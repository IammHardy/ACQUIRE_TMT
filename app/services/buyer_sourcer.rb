# Live buyer sourcing. Prefers Consulti.ai (verified B2B leads → grouped into
# potential-acquirer companies, each with a named decision-maker), falls back to
# Apollo, and Claude writes the per-buyer fit rationale. Returns the same shape
# as BuyerMatcher so it's a drop-in replacement when either provider is
# configured. Returns nil on any failure so the caller can fall back to the
# seeded Buyer dataset.
class BuyerSourcer
  # --- Consulti.ai (primary) ------------------------------------------------

  # Map our TMT sectors to Consulti's canonical b2b-industries enum values.
  CONSULTI_INDUSTRIES = {
    "saas"                 => ["Computer Software", "Information Technology & Services", "Internet"],
    "msp-it-services"      => ["Information Technology & Services", "Computer & Network Security"],
    "telecom-connectivity" => ["Telecommunications", "Wireless"],
    "digital-media"        => ["Online Media", "Media Production", "Broadcast Media", "Entertainment"],
    "cybersecurity"        => ["Computer & Network Security", "Computer Software"],
    "data-analytics-ai"    => ["Computer Software", "Information Technology & Services", "Information Services"],
    "cloud-infrastructure" => ["Computer Software", "Information Technology & Services"],
    "adtech-martech"       => ["Marketing & Advertising", "Computer Software"],
    "other"                => ["Information Technology & Services"]
  }.freeze

  # Decision-maker titles — who would lead/approve an acquisition.
  CONSULTI_TITLES = [
    "CEO", "Chief Executive Officer", "Founder", "Co-Founder", "President",
    "Managing Director", "Managing Partner", "Partner", "Corporate Development",
    "Head of Corporate Development", "VP of Corporate Development", "M&A",
    "Head of M&A", "Chief Strategy Officer"
  ].freeze

  # Title seniority ranking, most senior first, for picking one contact / company.
  SENIORITY = [
    /chief|ceo|founder|owner|president|managing partner|managing director/i,
    /partner|principal|corporate development|m&a|strategy/i,
    /vp|vice president|head/i,
    /director/i
  ].freeze

  CONSULTI_SOURCE = {
    activity: "Live results from Consulti.ai's verified B2B database, matched to your sector — each with a named decision-maker.",
    source:   { "name" => "Consulti.ai — live B2B data", "url" => "https://www.consulti.ai" }
  }.freeze

  # --- Apollo.io (fallback) -------------------------------------------------

  # Map our TMT sectors to Apollo keyword tags for finding strategic acquirers.
  SECTOR_KEYWORDS = {
    "saas"                 => ["SaaS", "enterprise software"],
    "msp-it-services"      => ["managed services", "IT services"],
    "telecom-connectivity" => ["telecommunications", "internet service provider"],
    "digital-media"        => ["digital media", "publishing"],
    "cybersecurity"        => ["cyber security", "information security"],
    "data-analytics-ai"    => ["data analytics", "artificial intelligence"],
    "cloud-infrastructure" => ["cloud computing", "hosting"],
    "adtech-martech"       => ["advertising technology", "marketing technology"],
    "other"                => ["technology"]
  }.freeze

  # Acquirer-scale headcounts (bigger than a typical small target).
  ACQUIRER_EMPLOYEE_RANGES = ["201,500", "501,1000", "1001,5000", "5001,10000"].freeze

  APOLLO_SOURCE = {
    activity: "Live results from Apollo's company database, matched to your sector and size.",
    source:   { "name" => "Apollo.io — live company data", "url" => "https://www.apollo.io" }
  }.freeze

  # --- Claude rationale -----------------------------------------------------

  RANK_SYSTEM = <<~PROMPT.freeze
    You are an M&A analyst. Given a target company and a list of candidate
    acquirers, write a one-sentence rationale for why each candidate could be a
    fit to acquire the target. Be specific and grounded only in the information
    provided; do not invent facts.
  PROMPT

  RANK_SCHEMA = {
    "type" => "object",
    "properties" => {
      "buyers" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "properties" => {
            "name" => { "type" => "string" },
            "rationale" => { "type" => "string", "description" => "One sentence on the acquisition fit." }
          },
          "required" => %w[name rationale],
          "additionalProperties" => false
        }
      }
    },
    "required" => ["buyers"],
    "additionalProperties" => false
  }.freeze

  CACHE_TTL = 24.hours

  # True when any live provider is configured (so the caller should try sourcing
  # before falling back to the seeded Buyer dataset).
  def self.live?
    ConsultiClient.configured? || ApolloClient.configured?
  end

  def initialize(industry:, revenue:, analysis: nil)
    @industry = ValuationData.sector_slug(industry)
    @revenue  = revenue.to_f
    @analysis = analysis || {}
  end

  def call
    buyers, meta = sourced_buyers
    return nil if buyers.blank?

    buyers = annotate_with_claude(buyers)

    {
      "industry"               => @industry,
      "industry_name"          => ValuationData.sector(@industry)["name"],
      "buyer_count"            => buyers.size,
      "acquisitions_last_year" => 0,
      "market_activity"        => meta[:activity],
      "categories"             => [{ "label" => "Strategic acquirers", "count" => buyers.size }],
      "buyers"                 => buyers,
      "sources"                => [meta[:source]],
      "as_of"                  => Time.current.strftime("%Y")
    }
  rescue => e
    Rails.logger.warn("[BuyerSourcer] #{e.class}: #{e.message}")
    nil
  end

  private

  # Pick a provider in priority order; the first that yields buyers wins.
  def sourced_buyers
    if ConsultiClient.configured?
      buyers = consulti_buyers
      return [buyers, CONSULTI_SOURCE] if buyers.present?
    end
    if ApolloClient.configured?
      buyers = apollo_buyers
      return [buyers, APOLLO_SOURCE] if buyers.present?
    end
    [nil, nil]
  end

  # --- Consulti path --------------------------------------------------------

  def consulti_buyers
    leads = cached_consulti_leads
    return [] if leads.blank?

    by_company = {}
    leads.each do |lead|
      name = lead["company_name"].to_s.strip
      key = name.downcase.gsub(/[^a-z0-9]/, "")  # merges "VividCloud" / "Vividcloud"
      next if key.blank?
      by_company[key] = lead if by_company[key].nil? || better_lead?(lead, by_company[key])
    end

    by_company.values
      .sort_by { |lead| lead["company_domain"].present? ? 0 : 1 }  # linkable companies first
      .first(8)
      .map { |lead| consulti_buyer(lead) }
  end

  # Pick the best representative contact for a company: prefer one with a website,
  # then the more senior title.
  def better_lead?(candidate, current)
    cand_domain = candidate["company_domain"].present? ? 1 : 0
    curr_domain = current["company_domain"].present? ? 1 : 0
    return cand_domain > curr_domain if cand_domain != curr_domain

    seniority(candidate) > seniority(current)
  end

  # The Consulti search (the credit-charged call) depends only on the sector, so
  # cache the lead list per sector for 24h. Only non-empty results are cached.
  def cached_consulti_leads
    key = "consulti_leads:v1:#{@industry}"
    cached = Rails.cache.read(key)
    return cached if cached.present?

    industries = CONSULTI_INDUSTRIES[@industry] || CONSULTI_INDUSTRIES["other"]
    leads = ConsultiClient.search_leads(
      { industries: industries, titles: CONSULTI_TITLES, countries: ["United States"], empMin: 50 },
      size: 25
    )
    # If the title-targeted search is empty, broaden to industry-only.
    if leads.blank?
      leads = ConsultiClient.search_leads({ industries: industries, countries: ["United States"] }, size: 25)
    end

    Rails.cache.write(key, leads, expires_in: CACHE_TTL) if leads.present?
    leads
  end

  def consulti_buyer(lead)
    domain  = lead["company_domain"].to_s.strip
    contact = [lead["first_name"], lead["last_name"]].compact_blank.join(" ").strip
    title   = lead["job_title"].to_s.strip
    base    = "Active #{ValuationData.sector(@industry)['name'].downcase} company and potential strategic acquirer."
    # Surface the decision-maker's name + role (no email/LinkedIn — that's paid data).
    rationale = if contact.present?
      "#{base} Decision-maker: #{contact}#{title.present? ? ", #{title}" : ''}."
    else
      base
    end

    {
      "name"         => lead["company_name"],
      "backed_by"    => nil,
      "rationale"    => rationale,
      "type_label"   => "Strategic acquirer",
      "acquisitions" => 0,
      "website"      => domain.present? ? "https://#{domain}" : nil
    }
  end

  def seniority(lead)
    title = lead["job_title"].to_s
    SENIORITY.each_with_index { |re, i| return SENIORITY.size - i if title.match?(re) }
    0
  end

  # --- Apollo path ----------------------------------------------------------

  def apollo_buyers
    orgs = fetch_orgs
    return [] if orgs.blank?

    orgs.first(6).map { |org| map_org(org) }
  end

  def fetch_orgs
    key = "apollo_acquirers:v1:#{@industry}"
    cached = Rails.cache.read(key)
    return cached if cached.present?

    orgs = ApolloClient.search_organizations(
      {
        q_organization_keyword_tags: SECTOR_KEYWORDS[@industry],
        organization_num_employees_ranges: ACQUIRER_EMPLOYEE_RANGES,
        organization_locations: ["United States"]
      },
      per_page: 10
    )
    Rails.cache.write(key, orgs, expires_in: CACHE_TTL) if orgs.present?
    orgs
  end

  def map_org(org)
    website = org["website_url"].presence || (org["primary_domain"].presence && "https://#{org['primary_domain']}")
    {
      "name"         => org["name"],
      "backed_by"    => nil,
      "rationale"    => org["short_description"].presence || "Active #{ValuationData.sector(@industry)['name']} company and potential strategic acquirer.",
      "type_label"   => "Strategic acquirer",
      "acquisitions" => 0,
      "website"      => website
    }
  end

  # --- Claude rationale -----------------------------------------------------

  # Replace the raw company blurbs with target-specific fit rationales via Claude.
  # Degrades gracefully to the provider descriptions if Claude is unavailable.
  def annotate_with_claude(buyers)
    return buyers unless ClaudeClient.configured?

    target = [@analysis["summary"], @analysis["business_model"]].compact.join(" ")
    target = "A #{ValuationData.sector(@industry)['name']} business." if target.blank?
    candidates = buyers.map { |b| "- #{b['name']}: #{b['rationale']}" }.join("\n")

    result = ClaudeClient.extract(
      system: RANK_SYSTEM,
      prompt: "Target company:\n#{target}\n\nCandidate acquirers:\n#{candidates}",
      schema: RANK_SCHEMA,
      tool_name: "record_rationales",
      max_tokens: 800
    )
    by_name = Array(result["buyers"]).index_by { |b| b["name"] }
    buyers.map do |buyer|
      rationale = by_name[buyer["name"]]&.dig("rationale")
      rationale.present? ? buyer.merge("rationale" => rationale) : buyer
    end
  rescue => e
    Rails.logger.warn("[BuyerSourcer] Claude annotate failed: #{e.class}: #{e.message}")
    buyers
  end
end

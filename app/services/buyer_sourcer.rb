# Live buyer sourcing: Apollo supplies the real, current company data and Claude
# writes the per-buyer fit rationale. Returns the same shape as BuyerMatcher so
# it's a drop-in replacement when APOLLO_API_KEY is configured. Returns nil on
# any failure so the caller can fall back to the seeded Buyer dataset.
class BuyerSourcer
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

  def initialize(industry:, revenue:, analysis: nil)
    @industry = ValuationData.sector_slug(industry)
    @revenue  = revenue.to_f
    @analysis = analysis || {}
  end

  def call
    orgs = fetch_orgs
    return nil if orgs.blank?

    buyers = orgs.first(6).map { |org| map_org(org) }
    buyers = annotate_with_claude(buyers)
    sector_name = ValuationData.sector(@industry)["name"]

    {
      "industry"               => @industry,
      "industry_name"          => sector_name,
      "buyer_count"            => orgs.size,
      "acquisitions_last_year" => 0,
      "market_activity"        => "Live results from Apollo's company database, matched to your sector and size.",
      "categories"             => [{ "label" => "Strategic acquirers", "count" => orgs.size }],
      "buyers"                 => buyers,
      "sources"                => [{ "name" => "Apollo.io — live company data", "url" => "https://www.apollo.io" }],
      "as_of"                  => Time.current.strftime("%Y")
    }
  rescue ApolloClient::NotConfigured
    nil
  rescue => e
    Rails.logger.warn("[BuyerSourcer] #{e.class}: #{e.message}")
    nil
  end

  private

  # The Apollo search (the credit-charged call) depends only on the sector, so
  # cache the org list per sector for 24h. Claude's per-seller rationale still
  # runs fresh on every request. Only successful, non-empty results are cached.
  CACHE_TTL = 24.hours

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

  # Replace the raw company blurbs with target-specific fit rationales via Claude.
  # Degrades gracefully to the Apollo descriptions if Claude is unavailable.
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

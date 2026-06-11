require "digest"

# Heuristic v1 buyer-universe engine for TMT businesses.
#
# Given a sector + revenue, it estimates how many active acquirers fit the
# profile and breaks them into strategic / PE-platform / search-fund buckets,
# plus a few illustrative buyer archetypes with acquisition rationale. Results
# are DETERMINISTIC for a given input (no randomness) — the simulated front-end
# previously rolled a random buyer count on every run, which undermined trust.
#
# Archetypes are sector-typed placeholders to be replaced in Phase 2 by real
# acquirer data (Searchfunder, SBA 7(a)/504 datasets, Crunchbase enrichment).
class BuyerMatcher
  # Illustrative size of the active-acquirer pool per sector.
  SECTOR_BUYER_POOL = {
    "saas"                 => 560,
    "msp-it-services"      => 620,
    "telecom-connectivity" => 300,
    "digital-media"        => 410,
    "cybersecurity"        => 480,
    "data-analytics-ai"    => 520,
    "cloud-infrastructure" => 440,
    "adtech-martech"       => 430,
    "other"                => 400
  }.freeze

  # Buyer archetypes per sector: [name, backed_by, rationale, recent_acquisitions]
  SECTOR_BUYERS = {
    "saas" => [
      ["Vertical SaaS Platform Co.", "PE-backed software platform", "Actively rolls up vertical SaaS businesses to expand product surface and cross-sell into adjacent recurring-revenue niches.", 12],
      ["Recurring Revenue Holdings", "Growth equity", "Acquires profitable bootstrapped SaaS with sticky retention and clear expansion paths.", 7],
      ["Application Software Group", "Strategic acquirer", "Buys workflow and B2B SaaS to broaden its application suite for SMB customers.", 21]
    ],
    "msp-it-services" => [
      ["Managed Services Consolidator", "PE-backed MSP platform", "Consolidates regional MSPs to build national managed-IT coverage and recurring contract density.", 18],
      ["IT Services Rollup Group", "Private equity", "Targets MSPs with strong recurring maintenance revenue and a stable SMB client base.", 14],
      ["Cloud & Helpdesk Partners", "Strategic acquirer", "Adds helpdesk and cloud-migration capabilities through bolt-on MSP acquisitions.", 9]
    ],
    "telecom-connectivity" => [
      ["Regional Connectivity Group", "PE-backed platform", "Rolls up fiber, broadband and managed-network operators to expand its footprint.", 11],
      ["Telecom Infrastructure Holdings", "Infrastructure fund", "Acquires connectivity providers with recurring subscriber revenue and network assets.", 8],
      ["Managed Network Partners", "Strategic acquirer", "Expands its enterprise connectivity portfolio via regional acquisitions.", 6]
    ],
    "digital-media" => [
      ["Digital Media Holdings", "PE-backed media platform", "Aggregates niche content brands with engaged audiences and subscription revenue.", 16],
      ["Audience & Content Group", "Growth equity", "Buys content properties with recurring traffic and monetizable audiences.", 9],
      ["Subscription Media Partners", "Strategic acquirer", "Adds subscription media brands to its portfolio to grow recurring revenue.", 7]
    ],
    "cybersecurity" => [
      ["Security Platform Co.", "PE-backed security platform", "Acquires MSSPs and security software to expand its managed-security stack.", 13],
      ["Cyber Defense Holdings", "Private equity", "Targets compliance, risk and security-software vendors with recurring contracts.", 10],
      ["Managed Security Partners", "Strategic acquirer", "Bolts on MSSP capabilities to serve enterprise security mandates.", 8]
    ],
    "data-analytics-ai" => [
      ["Data Platform Group", "PE-backed data platform", "Rolls up analytics and BI vendors to build an integrated data platform.", 12],
      ["AI & Analytics Holdings", "Growth equity", "Acquires AI-enabled SaaS with proprietary data assets and recurring revenue.", 9],
      ["Business Intelligence Partners", "Strategic acquirer", "Expands its analytics suite through targeted data-software acquisitions.", 7]
    ],
    "cloud-infrastructure" => [
      ["Cloud Services Consolidator", "PE-backed platform", "Consolidates hosting and managed-cloud providers to scale platform infrastructure.", 15],
      ["Managed Cloud Holdings", "Private equity", "Buys cloud-infrastructure businesses with recurring managed-services revenue.", 10],
      ["DevOps & Platform Partners", "Strategic acquirer", "Adds platform and DevOps capabilities through acquisitions.", 8]
    ],
    "adtech-martech" => [
      ["MarTech Platform Co.", "PE-backed platform", "Aggregates marketing-automation and AdTech tools into a unified martech stack.", 14],
      ["AdTech Data Holdings", "Growth equity", "Acquires AdTech data and performance-marketing SaaS with recurring revenue.", 9],
      ["Performance Marketing Partners", "Strategic acquirer", "Expands its martech portfolio via bolt-on acquisitions.", 7]
    ],
    "other" => [
      ["Technology Holdings Group", "PE-backed platform", "Acquires profitable technology-enabled businesses with recurring revenue.", 11],
      ["Software & Services Partners", "Private equity", "Targets tech-enabled services firms with stable, recurring cash flow.", 8],
      ["Digital Services Acquirer", "Strategic acquirer", "Adds complementary digital-services businesses to its portfolio.", 6]
    ]
  }.freeze

  def initialize(industry:, revenue:)
    @industry = SECTOR_BUYER_POOL.key?(industry) ? industry : "other"
    @revenue  = revenue.to_f
  end

  def call
    total = scaled_buyer_count

    {
      "industry"      => @industry,
      "industry_name" => ValuationEngine::INDUSTRY_NAMES[@industry],
      "buyer_count"   => total,
      "categories"    => [
        { "label" => "Strategic acquirers", "count" => (total * 0.45).round },
        { "label" => "PE-backed platforms", "count" => (total * 0.40).round },
        { "label" => "Search funds & individuals", "count" => (total * 0.15).round }
      ],
      "buyers" => SECTOR_BUYERS[@industry].map do |name, backed_by, rationale, acquisitions|
        {
          "name"          => name,
          "backed_by"     => backed_by,
          "rationale"     => rationale,
          "acquisitions"  => acquisitions
        }
      end
    }
  end

  private

  # Bigger businesses attract a wider strategic/PE buyer pool; smaller ones
  # skew toward search funds. Deterministic per input.
  def scaled_buyer_count
    base = SECTOR_BUYER_POOL[@industry]
    size_factor =
      if @revenue >= 10_000_000 then 1.0
      elsif @revenue >= 3_000_000 then 0.85
      elsif @revenue >= 1_000_000 then 0.7
      else 0.55
      end
    nudge = stable_int(0..80)
    ((base * size_factor) - 40 + nudge).round
  end

  def stable_int(range)
    seed = Digest::MD5.hexdigest("#{@industry}:#{@revenue.round}").to_i(16)
    range.min + (seed % (range.max - range.min + 1))
  end
end

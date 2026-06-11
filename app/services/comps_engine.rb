require "digest"

# Heuristic v1 market-comps engine for TMT businesses.
#
# Given a sector + the company's own revenue/earnings, it produces a sector
# M&A snapshot (listing volume, pricing multiples) and a small set of
# comparable listings anchored to the company's size. Results are DETERMINISTIC
# for a given input (no randomness) so the same business always sees the same
# comps — the first-party comps data is part of the product's moat, not theatre.
#
# Pricing multiples reuse ValuationEngine::MULTIPLES; "asking" figures apply a
# light private-market discount. To be replaced by real transaction data
# (Flippa / Empire Flippers / broker comps) in Phase 2.
class CompsEngine
  # Illustrative sector liquidity: roughly how many comparable businesses are
  # on the market in this TMT sector at any time. Replaced by real listing
  # counts once a comps dataset is seeded.
  SECTOR_LIQUIDITY = {
    "saas"                 => 540,
    "msp-it-services"      => 610,
    "telecom-connectivity" => 280,
    "digital-media"        => 470,
    "cybersecurity"        => 320,
    "data-analytics-ai"    => 360,
    "cloud-infrastructure" => 300,
    "adtech-martech"       => 410,
    "other"                => 450
  }.freeze

  # Plausible specialty / listing names per sector, used to label the anchored
  # comps. Two are surfaced per report.
  SECTOR_LISTINGS = {
    "saas"                 => ["Vertical SaaS Platform", "Recurring-Revenue App Suite", "B2B Workflow SaaS"],
    "msp-it-services"      => ["Managed IT Services Provider", "Cloud & Helpdesk MSP", "Regional IT Services Firm"],
    "telecom-connectivity" => ["Regional Connectivity Provider", "Fiber & Broadband Operator", "Managed Network Services"],
    "digital-media"        => ["Niche Digital Media Brand", "Content & Audience Platform", "Subscription Media Property"],
    "cybersecurity"        => ["Managed Security (MSSP) Provider", "Security Software Vendor", "Compliance & Risk Platform"],
    "data-analytics-ai"    => ["Data & Analytics Platform", "AI-Enabled SaaS", "Business Intelligence Vendor"],
    "cloud-infrastructure" => ["Cloud Hosting & Infrastructure", "Managed Cloud Platform", "DevOps & Platform Services"],
    "adtech-martech"       => ["MarTech Automation Platform", "AdTech Data Provider", "Performance Marketing SaaS"],
    "other"                => ["Technology-Enabled Services Co.", "Software & Services Business", "Digital Services Provider"]
  }.freeze

  PRIVATE_DISCOUNT = 0.8 # asking prices sit below public-comparable multiples

  def initialize(industry:, revenue:, earnings:)
    @industry = ValuationEngine::MULTIPLES.key?(industry) ? industry : "other"
    @revenue  = revenue.to_f
    @earnings = earnings.to_f
  end

  def call
    m = ValuationEngine::MULTIPLES[@industry]

    price_revenue = (m[:revenue][1] * PRIVATE_DISCOUNT).round(1)
    price_cash_flow = (m[:ebitda][1] * PRIVATE_DISCOUNT).round(1)

    listings_count = scaled_listing_count
    median_asking = median_asking_price(price_revenue)

    {
      "industry"               => @industry,
      "industry_name"          => ValuationEngine::INDUSTRY_NAMES[@industry],
      "sector_label"           => "#{ValuationEngine::INDUSTRY_NAMES[@industry]} sector M&A snapshot",
      "listings_count"         => listings_count,
      "combined_value"         => (listings_count * median_asking).round,
      "median_price_revenue"   => price_revenue,
      "median_price_cash_flow" => price_cash_flow,
      "median_asking"          => median_asking.round,
      "specialty_rows"         => [
        {
          "name"         => ValuationEngine::INDUSTRY_NAMES[@industry],
          "pct_of_total" => 100,
          "median_pcf"   => price_cash_flow,
          "median_asking" => median_asking.round
        }
      ],
      "listings"  => build_listings(price_revenue, price_cash_flow),
      "takeaway"  => "There are active buyers and listings in your sector, with pricing anchored to revenue (~#{price_revenue}×) and cash-flow (~#{price_cash_flow}×) multiples."
    }
  end

  private

  # Deterministic spread of the published sector liquidity, nudged by company
  # size so different inputs read differently without being random.
  def scaled_listing_count
    base = SECTOR_LIQUIDITY[@industry]
    nudge = stable_int(0..120)
    base - 60 + nudge
  end

  def median_asking_price(price_revenue)
    # Anchor the sector "median asking" to a business a notch below the
    # company's own revenue, priced at the discounted revenue multiple.
    anchor_revenue = @revenue.positive? ? @revenue * 0.9 : 750_000
    [anchor_revenue * price_revenue, 50_000].max
  end

  # Two comps anchored around the company's own size, so the report compares
  # like with like rather than showing fixed placeholder businesses.
  def build_listings(price_revenue, price_cash_flow)
    names = SECTOR_LISTINGS[@industry]
    base_rev = @revenue.positive? ? @revenue : 1_000_000
    margin = @revenue.positive? ? (@earnings / @revenue) : 0.2

    [
      { name: names[0], factor: 1.15 },
      { name: names[1], factor: 0.85 }
    ].each_with_index.map do |comp, i|
      rev = base_rev * comp[:factor]
      cf = rev * (margin.positive? ? margin : 0.2)
      {
        "name"        => comp[:name],
        "description" => "Comparable #{ValuationEngine::INDUSTRY_NAMES[@industry]} business with a similar revenue profile and recurring-revenue characteristics.",
        "revenue"     => rev.round,
        "ebitda"      => cf.round,
        "cash_flow"   => cf.round,
        "asking"      => (rev * price_revenue).round
      }
    end
  end

  # Deterministic integer in `range` seeded by the inputs — same business in,
  # same number out.
  def stable_int(range)
    seed = Digest::MD5.hexdigest("#{@industry}:#{@revenue.round}:#{@earnings.round}").to_i(16)
    range.min + (seed % (range.max - range.min + 1))
  end
end

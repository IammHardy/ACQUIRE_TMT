# Market-comps engine for TMT businesses, backed by the seeded Comp dataset.
#
# Given a sector + the company's own revenue/earnings, it pulls the comparable
# transactions for that sector (Comp rows, sourced from 2025 broker/marketplace
# data — see db/seeds.rb), computes real median pricing multiples, and surfaces
# the comps closest in size to the company. Pricing is therefore grounded in
# sourced data rather than a heuristic formula. Output keys are kept stable for
# the market-comps front-end; provenance (as_of / sources) is added on top.
class CompsEngine
  def initialize(industry:, revenue:, earnings:)
    @industry = ValuationData.sector_slug(industry)
    @revenue  = revenue.to_f
    @earnings = earnings.to_f
  end

  def call
    comps = Comp.matching(@industry, @revenue)
    return fallback if comps.empty?

    median_rev = Comp.median(comps.map(&:revenue_multiple))
    median_ebitda = Comp.median(comps.map(&:earnings_multiple))
    median_asking = Comp.median(comps.map(&:sale_price)).round
    sector_name = ValuationData.sector(@industry)["name"]

    {
      "industry"               => @industry,
      "industry_name"          => sector_name,
      "sector_label"           => "#{sector_name} sector — comparable transactions",
      "listings_count"         => comps.size,
      "combined_value"         => comps.sum { |c| c.sale_price.to_i },
      "median_price_revenue"   => median_rev.round(1),
      "median_price_cash_flow" => median_ebitda.round(1),
      "median_asking"          => median_asking,
      "specialty_rows"         => [
        {
          "name"          => sector_name,
          "pct_of_total"  => 100,
          "median_pcf"    => median_ebitda.round(1),
          "median_asking" => median_asking
        }
      ],
      "listings" => comps.first(4).map { |c| listing_for(c) },
      "takeaway" => "Based on #{comps.size} comparable #{sector_name} transactions, businesses in your sector are pricing around #{median_rev.round(1)}× revenue and #{median_ebitda.round(1)}× cash flow.",
      "as_of"    => "2025",
      "sources"  => comps.map { |c| { "name" => c.source, "url" => c.source_url } }.uniq { |s| s["name"] }
    }
  end

  private

  def listing_for(comp)
    {
      "name"        => comp.name,
      "description" => comp.description.to_s,
      "revenue"     => comp.revenue.to_i,
      "ebitda"      => comp.earnings.to_i,
      "cash_flow"   => comp.earnings.to_i,
      "asking"      => comp.sale_price.to_i
    }
  end

  # Only hit if the Comp table is empty (unseeded environment).
  def fallback
    sector_name = ValuationData.sector(@industry)["name"]
    {
      "industry"               => @industry,
      "industry_name"          => sector_name,
      "sector_label"           => "#{sector_name} sector — comparable transactions",
      "listings_count"         => 0,
      "combined_value"         => 0,
      "median_price_revenue"   => 0,
      "median_price_cash_flow" => 0,
      "median_asking"          => 0,
      "specialty_rows"         => [],
      "listings"               => [],
      "takeaway"               => "Comparable transaction data is being compiled for your sector.",
      "as_of"                  => "2025",
      "sources"                => []
    }
  end
end

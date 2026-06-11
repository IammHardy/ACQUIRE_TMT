# Valuation engine for TMT small businesses.
#
# Produces a low / midpoint / high enterprise-value range by blending a
# size-adjusted earnings (EBITDA/SDE) multiple with a sector revenue multiple.
# All multiples come from ValuationData, which is calibrated to free public
# datasets (Damodaran sector relativity + BizBuySell Main Street + Pepperdine
# lower-middle market) — see that file for provenance.
#
# Unlike a flat per-sector table, the earnings multiple scales with business
# size (a $200K-SDE shop and a $10M-EBITDA company price very differently),
# which is how private M&A actually works.
class ValuationEngine
  # Human-readable sector names, derived from the sourced ValuationData so the
  # other engines (CompsEngine, BuyerMatcher) share one source of truth.
  INDUSTRY_NAMES = ValuationData::SECTORS.transform_values { |s| s["name"] }.freeze

  # Backward-compatible representative multiples table for the comps/buyer
  # engines and the website-analyzer sector enum. Earnings multiples are shown
  # at a mid-size reference band ($1M–$3M); the valuation flow itself uses the
  # full size-aware logic in #call, not this snapshot.
  REFERENCE_EARNINGS_MULT = 4.2 # ValuationData::EARNINGS_BANDS mid band
  MULTIPLES = ValuationData::SECTORS.to_h do |slug, s|
    ebitda_mid  = REFERENCE_EARNINGS_MULT * s["earnings_factor"]
    revenue_mid = s["revenue_mult"]
    spread = ->(mid) { [mid * ValuationData::RANGE_LOW, mid, mid * ValuationData::RANGE_HIGH].map { |x| x.round(1) } }
    [slug, { ebitda: spread.call(ebitda_mid), revenue: spread.call(revenue_mid), weight: s["revenue_weight"] }]
  end.freeze

  # revenue, profit, salary_addback in dollars; industry is a slug.
  def initialize(industry:, revenue:, profit:, salary_addback: 0)
    @industry = ValuationData.sector_slug(industry)
    @revenue  = revenue.to_f
    @profit   = profit.to_f
    @earnings = @profit + salary_addback.to_f # adjusted earnings (SDE-style)
  end

  def call
    sector = ValuationData.sector(@industry)
    band = ValuationData.earnings_band(@earnings)
    w = sector["revenue_weight"]

    earnings_mult = band["mult"] * sector["earnings_factor"]
    revenue_mult  = sector["revenue_mult"]

    mid_raw = (@earnings * earnings_mult) * (1 - w) + (@revenue * revenue_mult) * w

    mid  = round_to_band(mid_raw)
    low  = round_to_band(mid_raw * ValuationData::RANGE_LOW)
    high = round_to_band(mid_raw * ValuationData::RANGE_HIGH)

    {
      "industry"                  => @industry,
      "industry_name"             => sector["name"],
      "revenue"                   => @revenue.round,
      "earnings"                  => @earnings.round,
      "margin_pct"                => margin_pct,
      "size_band"                 => band["label"],
      "low"                       => low,
      "midpoint"                  => mid,
      "high"                      => high,
      "implied_revenue_multiple"  => safe_ratio(mid, @revenue),
      "implied_earnings_multiple" => safe_ratio(mid, @earnings),
      "method"                    => "Size-adjusted blend: #{(w * 100).round}% revenue multiple / #{((1 - w) * 100).round}% earnings multiple",
      "as_of"                     => ValuationData::AS_OF,
      "sources"                   => ValuationData::SOURCES,
      "public_benchmark"          => ValuationData::PUBLIC_BENCHMARKS[@industry]
    }
  end

  private

  def margin_pct
    return 0 if @revenue.zero?

    ((@earnings / @revenue) * 100).round(1)
  end

  def safe_ratio(value, base)
    return 0 if base.zero?

    (value / base).round(1)
  end

  # Round to a sensible presentation band so the range reads like an estimate.
  def round_to_band(value)
    return 0 if value <= 0

    magnitude = 10**(Math.log10(value).floor - 1)
    magnitude = 1000 if magnitude < 1000
    (value / magnitude).round * magnitude
  end
end

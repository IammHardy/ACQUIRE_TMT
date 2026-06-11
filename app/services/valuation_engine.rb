# Heuristic v1 valuation engine for TMT businesses.
#
# Produces a low / midpoint / high enterprise-value range by blending an
# earnings (EBITDA/SDE) multiple with a revenue multiple, weighted by how
# recurring-revenue-driven the sector is. Multiples are illustrative TMT
# benchmarks (Pepperdine/BizBuySell-style), to be replaced by real comps data.
class ValuationEngine
  # ebitda: [low, mid, high] earnings multiples
  # revenue: [low, mid, high] revenue multiples
  # weight: fraction of the blend driven by the revenue method (0..1)
  MULTIPLES = {
    "saas"                 => { ebitda: [8, 12, 16], revenue: [2.5, 4.0, 6.0], weight: 0.6 },
    "msp-it-services"      => { ebitda: [5, 7, 9],   revenue: [1.0, 1.5, 2.5], weight: 0.3 },
    "telecom-connectivity" => { ebitda: [5, 7, 10],  revenue: [1.5, 2.5, 4.0], weight: 0.35 },
    "digital-media"        => { ebitda: [4, 6, 8],   revenue: [1.5, 2.5, 4.0], weight: 0.35 },
    "cybersecurity"        => { ebitda: [8, 11, 15], revenue: [3.0, 5.0, 8.0], weight: 0.55 },
    "data-analytics-ai"    => { ebitda: [8, 12, 16], revenue: [3.0, 5.0, 9.0], weight: 0.6 },
    "cloud-infrastructure" => { ebitda: [7, 10, 14], revenue: [2.5, 4.0, 7.0], weight: 0.5 },
    "adtech-martech"       => { ebitda: [6, 9, 12],  revenue: [2.0, 3.5, 6.0], weight: 0.45 },
    "other"                => { ebitda: [4, 6, 8],   revenue: [1.0, 2.0, 3.0], weight: 0.35 }
  }.freeze

  INDUSTRY_NAMES = {
    "saas"                 => "SaaS",
    "msp-it-services"      => "MSP / IT Services",
    "telecom-connectivity" => "Telecom & Connectivity",
    "digital-media"        => "Digital Media",
    "cybersecurity"        => "Cybersecurity",
    "data-analytics-ai"    => "Data, Analytics & AI",
    "cloud-infrastructure" => "Cloud Infrastructure",
    "adtech-martech"       => "AdTech / MarTech",
    "other"                => "Technology-enabled business"
  }.freeze

  # revenue, profit, salary_addback in dollars; industry is a slug.
  def initialize(industry:, revenue:, profit:, salary_addback: 0)
    @industry = MULTIPLES.key?(industry) ? industry : "other"
    @revenue  = revenue.to_f
    @profit   = profit.to_f
    @earnings = @profit + salary_addback.to_f # adjusted earnings (SDE-style)
  end

  def call
    m = MULTIPLES[@industry]

    earnings_vals = m[:ebitda].map { |x| @earnings * x }
    revenue_vals  = m[:revenue].map { |x| @revenue * x }
    w = m[:weight]

    low, mid, high = [0, 1, 2].map do |i|
      blended = earnings_vals[i] * (1 - w) + revenue_vals[i] * w
      round_to_band(blended)
    end

    {
      "industry"        => @industry,
      "industry_name"   => INDUSTRY_NAMES[@industry],
      "revenue"         => @revenue.round,
      "earnings"        => @earnings.round,
      "margin_pct"      => margin_pct,
      "low"             => low,
      "midpoint"        => mid,
      "high"            => high,
      "implied_revenue_multiple" => safe_ratio(mid, @revenue),
      "implied_earnings_multiple" => safe_ratio(mid, @earnings),
      "method" => "Blended #{(w * 100).round}% revenue / #{((1 - w) * 100).round}% earnings multiple"
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

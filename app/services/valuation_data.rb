# Sourced valuation reference data for TMT small businesses.
#
# This is the single source of truth behind ValuationEngine. The numbers are
# calibrated to three free, public datasets (cited in SOURCES) rather than
# invented:
#
#   1. NYU/Damodaran industry multiples (Jan 2026) — public-company EV/EBITDA
#      and EV/Sales by industry. Used for SECTOR RELATIVITY only (e.g. software
#      commands a premium to telecom services); the absolute public values are
#      NOT applied to small private businesses — they are 3-5x too high once
#      size and illiquidity are accounted for.
#   2. BizBuySell Insight Report (Q1 2026) — Main Street transaction reality:
#      ~2.6x median cash-flow (SDE) multiple, ~0.69x revenue multiple on
#      sub-$1M businesses. Anchors the small end of EARNINGS_BANDS.
#   3. Pepperdine Private Capital Markets Report (2025) — lower-middle-market
#      EBITDA multiples (~4.0x to >8.3x, rising with size). Anchors the large
#      end of EARNINGS_BANDS.
#
# Valuation is therefore SIZE-AWARE (bigger earnings -> higher multiple) and
# SECTOR-AWARE (recurring-revenue software sells higher than services), which
# is how private M&A actually prices businesses.
module ValuationData
  # Vintage of the underlying datasets — surfaced to users so the estimate is
  # transparent about how current it is.
  AS_OF = "Q1 2026".freeze

  SOURCES = [
    {
      "name" => "NYU Stern / Damodaran — Industry Multiples",
      "as_of" => "January 2026",
      "role" => "Public-company sector benchmarks (EV/EBITDA, EV/Sales) for sector relativity",
      "url" => "https://pages.stern.nyu.edu/~adamodar/New_Home_Page/datacurrent.html"
    },
    {
      "name" => "BizBuySell Insight Report",
      "as_of" => "Q1 2026",
      "role" => "Main Street private-transaction SDE & revenue multiples",
      "url" => "https://www.bizbuysell.com/insight-report/"
    },
    {
      "name" => "Pepperdine Private Capital Markets Report",
      "as_of" => "2025",
      "role" => "Lower-middle-market EBITDA multiples by deal size",
      "url" => "https://digitalcommons.pepperdine.edu/gsbm_pcm_pcmr/"
    }
  ].freeze

  # Public-company benchmarks (Damodaran, Jan 2026). Kept for citation and
  # sector relativity; private calibration below is what actually drives value.
  PUBLIC_BENCHMARKS = {
    "saas"                 => { "industry" => "Software (System & Application)", "ev_ebitda" => 24.48, "ev_sales" => 11.41 },
    "msp-it-services"      => { "industry" => "Computer Services",               "ev_ebitda" => 14.10, "ev_sales" => 1.48 },
    "telecom-connectivity" => { "industry" => "Telecom Services",                "ev_ebitda" => 6.54,  "ev_sales" => 2.61 },
    "digital-media"        => { "industry" => "Entertainment",                   "ev_ebitda" => 19.41, "ev_sales" => 4.33 },
    "cybersecurity"        => { "industry" => "Software (System & Application)", "ev_ebitda" => 24.48, "ev_sales" => 11.41 },
    "data-analytics-ai"    => { "industry" => "Information Services",            "ev_ebitda" => 11.50, "ev_sales" => 2.21 },
    "cloud-infrastructure" => { "industry" => "Computers/Peripherals",          "ev_ebitda" => 25.42, "ev_sales" => 6.63 },
    "adtech-martech"       => { "industry" => "Advertising",                     "ev_ebitda" => 12.00, "ev_sales" => 2.12 },
    "other"                => { "industry" => "Total Market",                    "ev_ebitda" => 19.73, "ev_sales" => 3.97 }
  }.freeze

  # Base ADJUSTED-EARNINGS (SDE / EBITDA) multiple by business size, for a
  # typical tech-enabled business. Small end = BizBuySell Main Street reality;
  # large end = Pepperdine lower-middle-market. The sector factor below scales
  # these up or down. `max` is the upper bound of adjusted earnings for the band.
  EARNINGS_BANDS = [
    { "max" => 250_000,             "mult" => 2.6, "label" => "Main Street (under $250K SDE)" },
    { "max" => 1_000_000,           "mult" => 3.3, "label" => "Small ($250K–$1M SDE)" },
    { "max" => 3_000_000,           "mult" => 4.2, "label" => "Lower-mid ($1M–$3M EBITDA)" },
    { "max" => 10_000_000,          "mult" => 5.3, "label" => "Mid ($3M–$10M EBITDA)" },
    { "max" => Float::INFINITY,     "mult" => 6.5, "label" => "Upper-mid ($10M+ EBITDA)" }
  ].freeze

  # Per-sector private-market calibration:
  #   earnings_factor — multiplier on the size-band base earnings multiple
  #                     (recurring-revenue software > services), informed by
  #                     Damodaran relativity but compressed to private reality.
  #   revenue_mult    — typical private revenue multiple for the sector at SMB
  #                     scale (anchored to BizBuySell ~0.69x baseline, scaled up
  #                     for high-multiple recurring sectors).
  #   revenue_weight  — fraction of the blended value driven by the revenue
  #                     method (higher where earnings understate value, e.g.
  #                     high-growth SaaS reinvesting profit).
  SECTORS = {
    "saas"                 => { "name" => "SaaS",                     "earnings_factor" => 1.35, "revenue_mult" => 3.2, "revenue_weight" => 0.55 },
    "cybersecurity"        => { "name" => "Cybersecurity",           "earnings_factor" => 1.30, "revenue_mult" => 2.6, "revenue_weight" => 0.50 },
    "data-analytics-ai"    => { "name" => "Data, Analytics & AI",    "earnings_factor" => 1.30, "revenue_mult" => 2.6, "revenue_weight" => 0.50 },
    "cloud-infrastructure" => { "name" => "Cloud Infrastructure",    "earnings_factor" => 1.20, "revenue_mult" => 1.9, "revenue_weight" => 0.45 },
    "adtech-martech"       => { "name" => "AdTech / MarTech",        "earnings_factor" => 1.05, "revenue_mult" => 1.4, "revenue_weight" => 0.40 },
    "digital-media"        => { "name" => "Digital Media",           "earnings_factor" => 0.95, "revenue_mult" => 1.1, "revenue_weight" => 0.35 },
    "msp-it-services"      => { "name" => "MSP / IT Services",       "earnings_factor" => 1.00, "revenue_mult" => 0.9, "revenue_weight" => 0.25 },
    "telecom-connectivity" => { "name" => "Telecom & Connectivity",  "earnings_factor" => 0.90, "revenue_mult" => 1.2, "revenue_weight" => 0.30 },
    "other"                => { "name" => "Technology-enabled business", "earnings_factor" => 1.00, "revenue_mult" => 0.8, "revenue_weight" => 0.30 }
  }.freeze

  # Spread applied around the midpoint to present a low/high range rather than a
  # false-precision point estimate.
  RANGE_LOW = 0.78
  RANGE_HIGH = 1.28

  module_function

  def sector(slug)
    SECTORS[slug] || SECTORS["other"]
  end

  def sector_slug(slug)
    SECTORS.key?(slug) ? slug : "other"
  end

  # Size-band base earnings multiple for a given adjusted-earnings figure.
  def earnings_band(earnings)
    EARNINGS_BANDS.find { |b| earnings <= b["max"] } || EARNINGS_BANDS.last
  end
end

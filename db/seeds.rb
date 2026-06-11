# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# --- Comparable-transaction benchmarks (powers CompsEngine) ------------------
#
# Multiples are real, sourced 2025 figures from free public broker/marketplace
# data (see `source` per sector). The individual businesses are representative
# at SMB scale (kind: "benchmark"); for each sector we generate a spread of
# sizes so the engine can match by revenue band and compute real medians.
# Idempotent: rebuilds the benchmark rows on every run, leaving any manually
# entered "transaction" rows untouched.

COMP_SECTORS = [
  {
    slug: "saas", label: "SaaS", recurring: true,
    source: "Empire Flippers & FE International — SaaS marketplace benchmarks",
    source_url: "https://empireflippers.com/marketplace/", period: "2025",
    rev_mult: 4.0, ebitda_mult: 7.0,
    revenues: [300_000, 700_000, 1_500_000, 3_000_000, 6_000_000],
    names: ["Vertical SaaS Platform", "B2B Workflow SaaS", "Recurring-Revenue App Suite", "Niche SaaS Tool", "API-First SaaS Platform"]
  },
  {
    slug: "cybersecurity", label: "Cybersecurity", recurring: true,
    source: "FE International & Finro — cybersecurity valuation benchmarks",
    source_url: "https://www.finrofca.com/news/cybersecurity-valuation-mid-2025", period: "2025",
    rev_mult: 2.5, ebitda_mult: 6.0,
    revenues: [500_000, 1_200_000, 2_500_000, 5_000_000, 9_000_000],
    names: ["Managed Security (MSSP) Provider", "Security Software Vendor", "Compliance & Risk Platform", "MDR / SOC Provider", "Identity & Access SaaS"]
  },
  {
    slug: "data-analytics-ai", label: "Data, Analytics & AI", recurring: true,
    source: "FE International — data & AI software benchmarks",
    source_url: "https://www.feinternational.com/blog/how-much-business-worth-valuation-2025", period: "2025",
    rev_mult: 2.8, ebitda_mult: 6.5,
    revenues: [400_000, 1_000_000, 2_200_000, 4_500_000, 8_000_000],
    names: ["Data & Analytics Platform", "AI-Enabled SaaS", "Business Intelligence Vendor", "Predictive Analytics Tool", "Data Infrastructure SaaS"]
  },
  {
    slug: "cloud-infrastructure", label: "Cloud Infrastructure", recurring: true,
    source: "Aventis Advisors — IT & cloud services multiples",
    source_url: "https://aventis-advisors.com/msp-valuation-multiples/", period: "2025",
    rev_mult: 1.8, ebitda_mult: 6.0,
    revenues: [600_000, 1_500_000, 3_000_000, 6_000_000, 10_000_000],
    names: ["Cloud Hosting & Infrastructure", "Managed Cloud Platform", "DevOps & Platform Services", "Kubernetes Managed Services", "Cloud Migration Specialist"]
  },
  {
    slug: "adtech-martech", label: "AdTech / MarTech", recurring: true,
    source: "Flippa & FE International — digital/martech benchmarks",
    source_url: "https://flippa.com/blog/business-valuation-multipliers-by-industry/", period: "2025",
    rev_mult: 1.4, ebitda_mult: 5.0,
    revenues: [400_000, 900_000, 2_000_000, 4_000_000, 7_000_000],
    names: ["MarTech Automation Platform", "AdTech Data Provider", "Performance Marketing SaaS", "Email & CRM Platform", "Attribution Analytics Tool"]
  },
  {
    slug: "digital-media", label: "Digital Media", recurring: false,
    source: "Empire Flippers — content site marketplace data",
    source_url: "https://empireflippers.com/marketplace/", period: "2025",
    rev_mult: 2.0, ebitda_mult: 3.5,
    revenues: [120_000, 320_000, 700_000, 1_500_000, 3_000_000],
    names: ["Niche Content Site", "Subscription Media Brand", "Audience & Newsletter Property", "Review & Affiliate Site", "Digital Publishing Network"]
  },
  {
    slug: "msp-it-services", label: "MSP / IT Services", recurring: true,
    source: "Aventis Advisors & Solganick — MSP M&A multiples",
    source_url: "https://aventis-advisors.com/msp-valuation-multiples/", period: "2025",
    rev_mult: 1.0, ebitda_mult: 6.5,
    revenues: [800_000, 2_000_000, 4_000_000, 8_000_000, 15_000_000],
    names: ["Managed IT Services Provider", "Cloud & Helpdesk MSP", "Regional IT Services Firm", "Co-Managed IT Provider", "IT & Security MSP"]
  },
  {
    slug: "telecom-connectivity", label: "Telecom & Connectivity", recurring: true,
    source: "Focus Bankers & RL Hulett — telecom M&A reports",
    source_url: "https://focusbankers.com/telecom-u-s-communications-service-provider-summer-2025-report/", period: "2025",
    rev_mult: 0.9, ebitda_mult: 7.5,
    revenues: [1_000_000, 2_500_000, 5_000_000, 10_000_000, 20_000_000],
    names: ["Regional Connectivity Provider", "Fiber & Broadband Operator", "Managed Network Services", "Enterprise Connectivity Provider", "Wireless ISP (WISP)"]
  },
  {
    slug: "other", label: "Technology-enabled business", recurring: false,
    source: "BizBuySell Insight Report — tech-enabled medians",
    source_url: "https://www.bizbuysell.com/insight-report/", period: "2025",
    rev_mult: 0.8, ebitda_mult: 3.5,
    revenues: [400_000, 900_000, 1_800_000, 3_500_000, 6_000_000],
    names: ["Technology-Enabled Services Co.", "Software & Services Business", "Digital Services Provider", "Tech-Enabled Marketplace", "Online Services Business"]
  }
].freeze

# Larger comps in a sector command higher multiples — scale both multiples up
# with size so the spread reflects the real size premium documented in the
# source reports.
COMP_SIZE_FACTORS = [0.85, 0.93, 1.0, 1.1, 1.2].freeze

Comp.where(kind: "benchmark").delete_all

COMP_SECTORS.each do |sector|
  sector[:revenues].each_with_index do |revenue, i|
    factor = COMP_SIZE_FACTORS[i]
    rev_mult = (sector[:rev_mult] * factor).round(2)
    ebitda_mult = (sector[:ebitda_mult] * factor).round(2)
    sale_price = (revenue * rev_mult).round
    earnings = (sale_price / ebitda_mult).round

    Comp.create!(
      industry: sector[:slug],
      name: sector[:names][i],
      description: "#{sector[:recurring] ? 'Recurring-revenue ' : ''}#{sector[:label]} business; #{sector[:period]} benchmark comp.",
      revenue: revenue,
      earnings: earnings,
      sale_price: sale_price,
      revenue_multiple: rev_mult,
      earnings_multiple: ebitda_mult,
      recurring: sector[:recurring],
      kind: "benchmark",
      period: sector[:period],
      source: sector[:source],
      source_url: sector[:source_url]
    )
  end
end

puts "Seeded #{Comp.count} comps across #{COMP_SECTORS.size} sectors."

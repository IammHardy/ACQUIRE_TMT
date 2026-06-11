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

# --- Active acquirers (powers BuyerMatcher) ----------------------------------
#
# Real, named buyers from public 2025 M&A reporting: PE roll-up platforms,
# strategic software acquirers, the search-fund / SBA buyer classes, and
# content aggregators. `sectors` lists the industry slugs each is active in;
# size bounds are in revenue dollars (nil = open-ended). Idempotent.

ALL_SECTORS = %w[saas msp-it-services telecom-connectivity digital-media cybersecurity
                 data-analytics-ai cloud-infrastructure adtech-martech other].freeze

BUYERS = [
  { name: "Evergreen Services Group", buyer_type: "pe_platform", backed_by: "Alpine Investors",
    thesis: "Acquires and permanently holds regional MSPs and IT-services firms with strong recurring revenue; ran ~47 acquisitions in 2025 and crossed $1B ARR.",
    sectors: %w[msp-it-services cybersecurity cloud-infrastructure], min_revenue: 1_000_000, max_revenue: 50_000_000,
    acquisitions_count: 47, source: "Omdia / CT Acquisitions — MSP M&A 2025", source_url: "https://ctacquisitions.com/guides/private-equity-msp-2026/" },
  { name: "New Charter Technologies", buyer_type: "pe_platform", backed_by: "Oval Partners",
    thesis: "National MSP roll-up acquiring established managed-IT providers as equity partners.",
    sectors: %w[msp-it-services cybersecurity], min_revenue: 2_000_000, max_revenue: 40_000_000,
    acquisitions_count: 12, source: "Omdia — MSP M&A 2025", source_url: "https://omdia.tech.informa.com/blogs/2026/apr/msp-m-and-a-2025-deals-focus-on-cybersecurity-ai" },
  { name: "Thrive", buyer_type: "pe_platform", backed_by: "Court Square Capital / Berkshire Partners",
    thesis: "Acquires MSPs and MSSPs to build a global managed-security and IT platform.",
    sectors: %w[msp-it-services cybersecurity cloud-infrastructure], min_revenue: 3_000_000, max_revenue: 60_000_000,
    acquisitions_count: 8, source: "Solganick — MSP/MSSP M&A 2025", source_url: "https://solganick.com/msp-mssp-mergers-acquisitions-report-2025/" },
  { name: "Ntiva", buyer_type: "pe_platform", backed_by: "PSP Capital",
    thesis: "Acquires regional MSPs to expand managed-IT and security coverage.",
    sectors: %w[msp-it-services cybersecurity], min_revenue: 1_000_000, max_revenue: 25_000_000,
    acquisitions_count: 6, source: "Omdia — MSP M&A 2025", source_url: "https://omdia.tech.informa.com/blogs/2026/apr/msp-m-and-a-2025-deals-focus-on-cybersecurity-ai" },
  { name: "Integris", buyer_type: "pe_platform", backed_by: "OMERS Private Equity",
    thesis: "Acquires MSPs to build a national managed-IT platform.",
    sectors: %w[msp-it-services], min_revenue: 2_000_000, max_revenue: 40_000_000,
    acquisitions_count: 7, source: "Omdia — MSP M&A 2025", source_url: "https://omdia.tech.informa.com/blogs/2026/apr/msp-m-and-a-2025-deals-focus-on-cybersecurity-ai" },
  { name: "Harbor IT", buyer_type: "pe_platform", backed_by: "Worklyn Partners",
    thesis: "Cybersecurity-focused platform acquiring MSSPs and security specialists (e.g. Quadrant Information Security).",
    sectors: %w[cybersecurity msp-it-services], min_revenue: 1_000_000, max_revenue: 30_000_000,
    acquisitions_count: 4, source: "MSSP Alert / Omdia — 2025", source_url: "https://www.msspalert.com/news/recent-acquisitions-illustrate-consolidation-trends-in-cybersecurity" },
  { name: "Constellation Software", buyer_type: "strategic", backed_by: "Public (TSX: CSU)",
    thesis: "Acquires and permanently holds vertical-market software with recurring revenue across 100+ markets (via Volaris, Harris, Topicus, Vela, Jonas, Perseus).",
    sectors: %w[saas data-analytics-ai adtech-martech other], min_revenue: 500_000, max_revenue: 100_000_000,
    acquisitions_count: 30, source: "Morningstar / Tracxn — 2025", source_url: "https://www.morningstar.com/company-reports/1457085-constellation-software-is-the-leading-vertical-saas-acquirer" },
  { name: "Volaris Group", buyer_type: "strategic", backed_by: "Constellation Software",
    thesis: "Buy-and-hold acquirer of vertical-market software with recurring revenue; 240+ acquisitions across 40 verticals.",
    sectors: %w[saas data-analytics-ai adtech-martech], min_revenue: 300_000, max_revenue: 50_000_000,
    acquisitions_count: 240, source: "Volaris / Constellation Software — 2025", source_url: "https://www.volarisgroup.com/" },
  { name: "Valsoft", buyer_type: "strategic", backed_by: "Private (Montreal holdco)",
    thesis: "Acquires and operates mission-critical vertical-market software; most active strategic SaaS buyer in 2025 (16 acquisitions).",
    sectors: %w[saas data-analytics-ai cybersecurity other], min_revenue: 500_000, max_revenue: 50_000_000,
    acquisitions_count: 16, source: "Software Equity Group — 2025", source_url: "https://softwareequity.com/blog/top-strategic-buyers" },
  { name: "ESW Capital (Trilogy)", buyer_type: "strategic", backed_by: "ESW Capital",
    thesis: "Acquires enterprise software businesses and consolidates them via its Crossover / Trilogy operating model.",
    sectors: %w[saas data-analytics-ai], min_revenue: 1_000_000, max_revenue: 100_000_000,
    acquisitions_count: 10, source: "Hampleton Partners — enterprise software acquirers", source_url: "https://www.hampletonpartners.com/news/newsdetail/who-are-the-top-5-enterprise-software-acquirers/" },
  { name: "Content & brand aggregators", buyer_type: "aggregator", backed_by: "Aggregator funds",
    thesis: "Acquire profitable content sites, newsletters and digital-media brands to roll into larger portfolios.",
    sectors: %w[digital-media adtech-martech], min_revenue: 100_000, max_revenue: 10_000_000,
    acquisitions_count: 0, source: "Empire Flippers — content site marketplace", source_url: "https://empireflippers.com/content-site-goldrush/" },
  { name: "Regional fiber & ISP consolidators", buyer_type: "pe_platform", backed_by: "Infrastructure investors",
    thesis: "Roll up regional ISPs, fiber and connectivity operators for subscriber and network scale.",
    sectors: %w[telecom-connectivity], min_revenue: 1_000_000, max_revenue: 100_000_000,
    acquisitions_count: 0, source: "Focus Bankers / CoBank — telecom M&A 2025", source_url: "https://focusbankers.com/telecom-u-s-communications-service-provider-summer-2025-report/" },
  { name: "Digital-infrastructure funds", buyer_type: "pe_platform", backed_by: "Infrastructure private equity",
    thesis: "Acquire connectivity and managed-network operators with recurring subscriber revenue.",
    sectors: %w[telecom-connectivity cloud-infrastructure], min_revenue: 3_000_000, max_revenue: 150_000_000,
    acquisitions_count: 0, source: "RL Hulett / CoBank — telecom M&A 2025", source_url: "https://rlhulett.com/" },
  { name: "Search-fund acquirers (Searchfunder network)", buyer_type: "search_fund", backed_by: "Search-fund investors",
    thesis: "Individual operators backed by search-fund investors acquiring one profitable business ($1–10M revenue) to own and run.",
    sectors: ALL_SECTORS, min_revenue: 1_000_000, max_revenue: 15_000_000,
    acquisitions_count: 0, source: "Searchfunder / Stanford GSB search-fund studies", source_url: "https://www.searchfunder.com/" },
  { name: "SBA 7(a) individual buyers", buyer_type: "sba", backed_by: "SBA 7(a) financing",
    thesis: "Owner-operators acquiring established small businesses (deals up to ~$5M) with SBA-backed acquisition loans.",
    sectors: ALL_SECTORS, min_revenue: 0, max_revenue: 6_000_000,
    acquisitions_count: 0, source: "U.S. SBA 7(a) program / Live Oak Bank", source_url: "https://www.sba.gov/funding-programs/loans" }
].freeze

Buyer.delete_all
BUYERS.each { |attrs| Buyer.create!(attrs) }

puts "Seeded #{Buyer.count} active acquirers."

# --- Sample deal listings (buyer deal feed) ----------------------------------
# Anonymized TMT businesses for sale. Idempotent.

DEALS = [
  { reference: "TMT-001", title: "Profitable Vertical SaaS for Dental Practices", industry: "saas",
    revenue: 2_400_000, ebitda: 720_000, asking_price: 9_500_000, location: "US — Remote", recurring: true,
    teaser: "Founder-led vertical SaaS serving dental practices with sticky, mission-critical workflows.",
    highlights: ["92% gross retention", "85% recurring revenue", "Lean, profitable team"] },
  { reference: "TMT-002", title: "Regional Managed IT Services Provider", industry: "msp-it-services",
    revenue: 6_000_000, ebitda: 1_200_000, asking_price: 7_800_000, location: "Midwest US", recurring: true,
    teaser: "Established MSP with a dense base of contracted SMB clients and strong recurring revenue.",
    highlights: ["140+ contracted clients", "78% revenue under MRR", "Experienced technician bench"] },
  { reference: "TMT-003", title: "MSSP with 24/7 Security Operations Center", industry: "cybersecurity",
    revenue: 4_200_000, ebitda: 900_000, asking_price: 6_300_000, location: "US — Remote", recurring: true,
    teaser: "Managed security provider with an in-house SOC and compliance services for mid-market clients.",
    highlights: ["90%+ recurring revenue", "SOC2 + compliance offering", "Enterprise customer logos"] },
  { reference: "TMT-004", title: "Niche Content & Newsletter Network", industry: "digital-media",
    revenue: 1_100_000, ebitda: 620_000, asking_price: 2_400_000, location: "Remote", recurring: false,
    teaser: "Audience-driven content network with a large engaged newsletter list and diversified monetization.",
    highlights: ["480K newsletter subscribers", "Ad + affiliate + subscription mix", "60%+ margins"] },
  { reference: "TMT-005", title: "Regional Fiber & Connectivity Operator", industry: "telecom-connectivity",
    revenue: 9_000_000, ebitda: 2_700_000, asking_price: 22_000_000, location: "Southeast US", recurring: true,
    teaser: "Connectivity operator with owned fiber assets and a recurring residential + enterprise subscriber base.",
    highlights: ["Owned fiber infrastructure", "Recurring subscriber revenue", "Clear expansion runway"] },
  { reference: "TMT-006", title: "AI-Enabled Analytics SaaS", industry: "data-analytics-ai",
    revenue: 3_500_000, ebitda: 700_000, asking_price: 11_000_000, location: "US / EU — Remote", recurring: true,
    teaser: "Analytics platform with a proprietary data asset and strong expansion within enterprise accounts.",
    highlights: ["Proprietary data moat", "120% net revenue retention", "Enterprise sales pipeline"] },
  { reference: "TMT-007", title: "Managed Cloud & DevOps Platform", industry: "cloud-infrastructure",
    revenue: 5_500_000, ebitda: 1_100_000, asking_price: 9_000_000, location: "Remote", recurring: true,
    teaser: "Managed cloud and DevOps services business with multi-year contracts and sticky platform revenue.",
    highlights: ["Multi-year contracts", "AWS & Azure partner status", "High net revenue retention"] },
  { reference: "TMT-008", title: "Performance Marketing SaaS", industry: "adtech-martech",
    revenue: 2_000_000, ebitda: 520_000, asking_price: 3_200_000, location: "Remote", recurring: true,
    teaser: "MarTech platform blending self-serve subscriptions with managed performance campaigns.",
    highlights: ["Self-serve + managed revenue", "Recurring subscriptions", "Strong unit economics"] },
  { reference: "TMT-009", title: "Bootstrapped B2B Workflow SaaS", industry: "saas",
    revenue: 750_000, ebitda: 300_000, asking_price: 2_600_000, location: "Remote", recurring: true,
    teaser: "Profitable bootstrapped B2B SaaS with low churn; owner looking to transition out.",
    highlights: ["~70% margins", "Low monthly churn", "Clean, documented codebase"] },
  { reference: "TMT-010", title: "Cybersecurity-Focused MSP Platform", industry: "msp-it-services",
    revenue: 14_000_000, ebitda: 3_200_000, asking_price: 32_000_000, location: "National US", recurring: true,
    teaser: "Scaled MSP with embedded security services — a platform-ready asset for a roll-up.",
    highlights: ["Embedded MDR/EDR security", "90%+ recurring revenue", "PE platform-ready"] }
].freeze

GREEK = %w[Alpha Beta Gamma Delta Epsilon Zeta Eta Theta Iota Kappa].freeze

Deal.delete_all
DEALS.each_with_index { |attrs, i| Deal.create!(attrs.merge(codename: GREEK[i % GREEK.size])) }

puts "Seeded #{Deal.count} deal listings."

class Public::IndustriesController < ApplicationController
  INDUSTRIES = {
    "saas" => {
      name: "SaaS",
      tagline: "Recurring revenue businesses with strong buyer demand.",
      intro: "Software-as-a-Service companies are valued on recurring revenue quality, retention, and growth efficiency. AcquireTMT helps SaaS founders frame ARR, churn, and expansion in the language buyers underwrite against.",
      value_drivers: [
        "ARR / MRR scale and growth rate",
        "Net revenue retention and logo churn",
        "Gross margin and rule-of-40 profile",
        "Customer concentration and contract length"
      ],
      buyers: [
        "Strategic software acquirers",
        "PE-backed SaaS platforms (roll-ups)",
        "Growth equity and buyout funds",
        "Search funds and independent sponsors"
      ]
    },
    "msp-it-services" => {
      name: "MSP / IT Services",
      tagline: "Managed services with sticky, contracted revenue.",
      intro: "Managed service providers and IT services firms attract acquirers seeking recurring contracts, technician capacity, and cross-sell into cybersecurity and cloud. AcquireTMT positions service mix and margin for the right buyer.",
      value_drivers: [
        "Share of recurring / contracted revenue",
        "Managed services vs. project mix",
        "Technician utilization and margin",
        "Vendor relationships and certifications"
      ],
      buyers: [
        "National MSP platforms and roll-ups",
        "PE-backed managed services consolidators",
        "Strategic IT and telecom acquirers",
        "Regional competitors seeking scale"
      ]
    },
    "telecom-connectivity" => {
      name: "Telecom & Connectivity",
      tagline: "Fiber, VoIP, wireless, and managed connectivity.",
      intro: "Connectivity businesses are valued on network assets, subscriber economics, and recurring access revenue. AcquireTMT helps owners present infrastructure and churn in a way infrastructure buyers reward.",
      value_drivers: [
        "Recurring access / subscriber revenue",
        "Network footprint and assets",
        "Churn and average revenue per user",
        "Contract terms and enterprise mix"
      ],
      buyers: [
        "Infrastructure funds and platforms",
        "Strategic carriers and ISPs",
        "PE-backed connectivity roll-ups",
        "Regional telecom operators"
      ]
    },
    "digital-media" => {
      name: "Digital Media",
      tagline: "Content sites, newsletters, communities, and podcasts.",
      intro: "Digital media portfolios are valued on audience, monetization durability, and traffic diversification. AcquireTMT helps owners frame revenue quality across advertising, subscriptions, and commerce.",
      value_drivers: [
        "Audience size and engagement",
        "Revenue diversification and durability",
        "Traffic source concentration",
        "Subscription / membership revenue"
      ],
      buyers: [
        "Strategic media and publishing groups",
        "Digital media holding companies",
        "PE-backed content roll-ups",
        "Operators and portfolio buyers"
      ]
    },
    "cybersecurity" => {
      name: "Cybersecurity",
      tagline: "MSSPs, security software, and compliance services.",
      intro: "Security businesses command premium attention from strategics and platforms consolidating the market. AcquireTMT helps frame recurring security revenue, certifications, and threat coverage for acquirers.",
      value_drivers: [
        "Recurring security / monitoring revenue",
        "Certifications and compliance coverage",
        "Customer retention and contract length",
        "Proprietary tooling and SOC capability"
      ],
      buyers: [
        "Strategic security software acquirers",
        "PE-backed MSSP platforms",
        "Managed services consolidators",
        "Growth equity investors"
      ]
    },
    "data-analytics-ai" => {
      name: "Data, Analytics & AI",
      tagline: "Analytics platforms, AI tools, and data services.",
      intro: "Data and AI businesses are valued on proprietary data, model defensibility, and recurring platform revenue. AcquireTMT helps founders articulate technical moat alongside commercial traction.",
      value_drivers: [
        "Proprietary data assets and rights",
        "Recurring platform revenue",
        "Model / IP defensibility",
        "Enterprise customer concentration"
      ],
      buyers: [
        "Strategic software and data acquirers",
        "PE-backed analytics platforms",
        "Growth equity and venture buyers",
        "Enterprise and infrastructure strategics"
      ]
    },
    "cloud-infrastructure" => {
      name: "Cloud Infrastructure",
      tagline: "Hosting, DevOps, observability, and automation.",
      intro: "Cloud infrastructure companies are valued on recurring consumption revenue, reliability, and stickiness. AcquireTMT helps owners present usage economics and retention to infrastructure buyers.",
      value_drivers: [
        "Recurring / consumption revenue",
        "Gross margin and infrastructure efficiency",
        "Net retention and expansion",
        "Reliability and switching costs"
      ],
      buyers: [
        "Strategic infrastructure software acquirers",
        "PE-backed cloud platforms",
        "Hosting and DevOps consolidators",
        "Growth equity investors"
      ]
    },
    "adtech-martech" => {
      name: "AdTech / MarTech",
      tagline: "Attribution, CRM, media buying, and engagement tools.",
      intro: "AdTech and MarTech businesses are valued on platform revenue, data signal, and integration depth. AcquireTMT helps founders frame recurring revenue and customer stickiness for strategic and financial buyers.",
      value_drivers: [
        "Recurring platform / SaaS revenue",
        "Customer retention and integration depth",
        "Proprietary data and signal",
        "Revenue concentration and spend exposure"
      ],
      buyers: [
        "Strategic marketing software acquirers",
        "PE-backed martech platforms",
        "AdTech consolidators and holdcos",
        "Growth equity investors"
      ]
    }
  }.freeze

  def show
    @industry = INDUSTRIES[params[:slug]]

    unless @industry
      render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
      return
    end

    @slug = params[:slug]
  end
end

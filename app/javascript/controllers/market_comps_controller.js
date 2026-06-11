import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "websiteStep",
    "financialStep",
    "loadingStep",
    "reportStep",
    "error",
    "websiteInput",
    "ctaWebsiteInput",
    "companyName",
    "revenueInput",
    "profitInput",
    "salaryInput",
    "progressBar",
    "progressText",
    "loadingTitle",
    "loadingDescription",
    "stepList",
    "previewIntro",
    "previewProducts",
    "previewMarkets",
    "sectorLabel",
    "listingsCount",
    "combinedValue",
    "medianPriceRevenue",
    "medianPriceCashFlow",
    "takeaway",
    "specialtyRows",
    "listings",
    "compsSources",
    "compsAsOf"
  ]

  connect() {
    this.messages = [
      ["Analyzing website data", "Reviewing business model and company signals."],
      ["Identifying industry category", "Mapping your business to the closest TMT sector."],
      ["Evaluating business model", "Checking recurring revenue, services mix, and market positioning."],
      ["Finding comparable listings", "Searching similar businesses and recent market activity."],
      ["Analyzing financial metrics", "Comparing revenue, profit, cash flow, and pricing signals."],
      ["Benchmarking performance", "Preparing a market comps snapshot for your business."]
    ]
  }

  showFinancials(event) {
    event.preventDefault()
    this.clearError()

    const website = this.websiteInputTarget.value.trim()

    if (!website) {
      this.showError("Please enter your company website.")
      return
    }

    this.companyNameTargets.forEach((target) => {
      target.textContent = this.extractCompanyName(website)
    })

    this.websiteStepTarget.classList.add("hidden")
    this.financialStepTarget.classList.remove("hidden")
  }

  startFromCta(event) {
    event.preventDefault()

    const website = this.ctaWebsiteInputTarget.value.trim()

    if (!website) {
      this.showError("Please enter your company website.")
      return
    }

    this.websiteInputTarget.value = website
    this.companyNameTargets.forEach((target) => {
      target.textContent = this.extractCompanyName(website)
    })

    this.websiteStepTarget.classList.add("hidden")
    this.loadingStepTarget.classList.add("hidden")
    this.reportStepTarget.classList.add("hidden")
    this.financialStepTarget.classList.remove("hidden")

    document.getElementById("market-comps-tool")?.scrollIntoView({
      behavior: "smooth",
      block: "start"
    })
  }

  async startReport(event) {
    event.preventDefault()
    this.clearError()

    const website = this.websiteInputTarget.value.trim()
    const revenue = Number(this.revenueInputTarget.value)
    const profit = Number(this.profitInputTarget.value)

    if (!revenue || !profit) {
      this.showError("Please enter your revenue and pre-tax profit.")
      return
    }

    if (profit > revenue) {
      this.showError("Pre-tax profit cannot be greater than annual revenue.")
      return
    }

    this.financialStepTarget.classList.add("hidden")
    this.loadingStepTarget.classList.remove("hidden")

    // Kick off the real comps analysis alongside the loading animation.
    this.requestSettled = false
    this.compsData = null
    const requestPromise = this.requestComps({ website, revenue, profit })

    let progress = 0
    let messageIndex = -1

    this.stepListTarget.innerHTML = ""
    this.progressBarTarget.style.width = "0%"
    this.progressTextTarget.textContent = "0%"
    this.previewIntroTarget.classList.add("hidden")
    this.previewProductsTarget.classList.add("hidden")
    this.previewMarketsTarget.classList.add("hidden")

    const interval = setInterval(() => {
      const cap = this.requestSettled ? 100 : 92
      progress += Math.floor(Math.random() * 8) + 5
      if (progress >= cap) progress = cap

      this.progressBarTarget.style.width = `${progress}%`
      this.progressTextTarget.textContent = `${progress}%`

      if (progress >= 45) this.previewIntroTarget.classList.remove("hidden")
      if (progress >= 65) this.previewProductsTarget.classList.remove("hidden")
      if (progress >= 80) this.previewMarketsTarget.classList.remove("hidden")

      const nextIndex = Math.min(
        Math.floor((progress / 100) * this.messages.length),
        this.messages.length - 1
      )

      if (nextIndex !== messageIndex) {
        messageIndex = nextIndex
        const [title, description] = this.messages[messageIndex]

        this.loadingTitleTarget.textContent = title
        this.loadingDescriptionTarget.textContent = description
        this.addProcessingStep(title, description)
      }

      if (progress === 100) {
        clearInterval(interval)

        setTimeout(() => {
          if (this.compsData) this.populateReport(this.compsData)
          this.loadingStepTarget.classList.add("hidden")
          this.reportStepTarget.classList.remove("hidden")
        }, 900)
      }
    }, 500)

    try {
      this.compsData = await requestPromise
      this.requestSettled = true
    } catch (error) {
      this.requestSettled = true
      clearInterval(interval)
      this.loadingStepTarget.classList.add("hidden")
      this.financialStepTarget.classList.remove("hidden")
      this.showError(error.message || "Something went wrong generating your comps report.")
    }
  }

  async requestComps({ website, revenue, profit }) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    const response = await fetch("/tools/market-comps/analyze", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": token || ""
      },
      body: JSON.stringify({ website, revenue, profit })
    })

    const data = await response.json().catch(() => ({}))
    if (!response.ok) {
      throw new Error(data.error || "We couldn't generate your comps report. Please try again.")
    }
    return data
  }

  populateReport(data) {
    const a = data.analysis || {}
    const c = data.comps || {}

    this.setText("sectorLabel", c.sector_label || `${a.industry_name || "TMT"} sector M&A snapshot`)
    this.setText("listingsCount", c.listings_count != null ? String(c.listings_count) : "—")
    this.setText("combinedValue", this.formatCurrency(c.combined_value))
    this.setText("medianPriceRevenue", c.median_price_revenue != null ? `${c.median_price_revenue}×` : "—")
    this.setText("medianPriceCashFlow", c.median_price_cash_flow != null ? `${c.median_price_cash_flow}×` : "—")
    this.setText("takeaway", c.takeaway || "")

    this.companyNameTargets.forEach((t) => {
      if (a.company_name) t.textContent = a.company_name
    })

    if (c.as_of) this.setText("compsAsOf", c.as_of)
    this.renderSpecialtyRows(c.specialty_rows || [])
    this.renderListings(c.listings || [], a)
    this.renderSources(c.sources || [])
  }

  renderSources(sources) {
    if (!this.hasCompsSourcesTarget) return

    this.compsSourcesTarget.innerHTML = ""
    if (!sources.length) {
      this.compsSourcesTarget.innerHTML = `<li class="text-slate-500">Comparable transaction data is being compiled for your sector.</li>`
      return
    }
    sources.forEach((src) => {
      const li = document.createElement("li")
      li.className = "flex gap-2"
      const name = this.escapeHtml(src.name || "Market data")
      const link = src.url
        ? `<a href="${src.url}" target="_blank" rel="noopener" class="font-semibold text-brand-500 hover:underline">${name}</a>`
        : `<span class="font-semibold text-brand-900">${name}</span>`
      li.innerHTML = `<span class="text-brand-300">•</span><span>${link}</span>`
      this.compsSourcesTarget.appendChild(li)
    })
  }

  renderSpecialtyRows(rows) {
    if (!this.hasSpecialtyRowsTarget || !rows.length) return

    this.specialtyRowsTarget.innerHTML = ""
    rows.forEach((row) => {
      const tr = document.createElement("tr")
      tr.className = "border-t border-brand-100"
      tr.innerHTML = `
        <td class="p-4">${this.escapeHtml(row.name)}</td>
        <td class="p-4">${row.pct_of_total}%</td>
        <td class="p-4">${row.median_pcf}×</td>
        <td class="p-4">${this.formatCurrency(row.median_asking)}</td>
      `
      this.specialtyRowsTarget.appendChild(tr)
    })
  }

  renderListings(listings, analysis) {
    if (!this.hasListingsTarget || !listings.length) return

    this.listingsTarget.innerHTML = ""
    listings.forEach((listing) => {
      const card = document.createElement("div")
      card.className = "rounded-sm border border-brand-100 bg-brand-50 p-5"
      card.innerHTML = `
        <h4 class="font-serif text-2xl font-medium text-brand-900">${this.escapeHtml(listing.name)}</h4>
        <p class="mt-3 text-sm leading-6 text-slate-600">${this.escapeHtml(listing.description || "")}</p>
        <div class="mt-5 grid grid-cols-3 gap-3 text-sm">
          <div>
            <p class="text-slate-500">Revenue</p>
            <p class="font-bold text-brand-900">${this.formatCurrency(listing.revenue)}</p>
          </div>
          <div>
            <p class="text-slate-500">EBITDA</p>
            <p class="font-bold text-brand-900">${this.formatCurrency(listing.ebitda)}</p>
          </div>
          <div>
            <p class="text-slate-500">Cash Flow</p>
            <p class="font-bold text-brand-900">${this.formatCurrency(listing.cash_flow)}</p>
          </div>
        </div>
      `
      this.listingsTarget.appendChild(card)
    })
  }

  setText(name, value) {
    const cap = name.charAt(0).toUpperCase() + name.slice(1)
    if (this[`has${cap}Target`]) this[`${name}Target`].textContent = value
  }

  showError(message) {
    if (!this.hasErrorTarget) { window.alert(message); return }
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
    this.errorTarget.scrollIntoView({ behavior: "smooth", block: "center" })
  }

  clearError() {
    if (this.hasErrorTarget) this.errorTarget.classList.add("hidden")
  }

  formatCurrency(value) {
    const n = Number(value) || 0
    if (n >= 1_000_000) {
      const m = n / 1_000_000
      return `$${m % 1 === 0 ? m.toFixed(0) : m.toFixed(1)}M`
    }
    if (n >= 1_000) return `$${Math.round(n / 1_000)}K`
    return `$${n}`
  }

  escapeHtml(value) {
    const div = document.createElement("div")
    div.textContent = String(value)
    return div.innerHTML
  }

  addProcessingStep(title, description) {
    const item = document.createElement("div")

    item.className =
      "flex gap-3 rounded-sm border border-brand-100 bg-white p-4 shadow-soft animate-fade-up"

    item.innerHTML = `
      <div class="mt-1 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-brand-300 text-brand-900">
        ✓
      </div>

      <div>
        <p class="text-sm font-bold text-brand-900">${title}</p>
        <p class="mt-1 text-xs leading-5 text-slate-600">${description}</p>
      </div>
    `

    this.stepListTarget.prepend(item)
  }

  backToWebsite(event) {
    event.preventDefault()

    this.financialStepTarget.classList.add("hidden")
    this.websiteStepTarget.classList.remove("hidden")
  }

  extractCompanyName(url) {
    try {
      const parsedUrl = new URL(url.startsWith("http") ? url : `https://${url}`)
      return parsedUrl.hostname.replace("www.", "").split(".")[0]
    } catch {
      return "Your Business"
    }
  }
}

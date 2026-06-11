import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "websiteStep",
    "financialStep",
    "loadingStep",
    "resultsStep",
    "detailsStep",
    "error",
    "websiteInput",
    "ctaWebsiteInput",
    "websitePreview",
    "companyName",
    "revenueRange",
    "profitRange",
    "progressBar",
    "progressText",
    "loadingTitle",
    "loadingDescription",
    "buyerCount",
    "acquisitionsLastYear",
    "marketActivity",
    "categories",
    "buyerCards",
    "buyerSources",
    "buyerAsOf",
    "attemptCounter"
  ]

  connect() {
    this.progressMessages = [
      ["Analyzing website", "Reviewing company signals and business context."],
      ["Checking industry", "Identifying likely TMT category and buyer fit."],
      ["Reviewing revenue profile", "Mapping size range to likely acquisition interest."],
      ["Searching buyer database", "Scanning strategic acquirers, PE platforms and active mandates."],
      ["Finding potential buyers", "Matching buyer categories to your company profile."],
      ["Preparing BuyerMap", "Generating your preliminary buyer universe preview."]
    ]
    this.maxAttempts = 2
    this.storageKey = "buyer_map_attempts"
    this.updateAttemptCounter()
  }

  getAttempts() {
    return Number(localStorage.getItem(this.storageKey) || 0)
  }

  setAttempts(count) {
    localStorage.setItem(this.storageKey, count)
    this.updateAttemptCounter()
  }

  updateAttemptCounter() {
    if (!this.hasAttemptCounterTarget) return

    const attempts = this.getAttempts()
    const displayCount = Math.min(attempts + 1, this.maxAttempts)

    this.attemptCounterTarget.textContent = `${displayCount}/${this.maxAttempts}`
  }

  canRunSearch() {
    return this.getAttempts() < this.maxAttempts
  }

  recordAttempt() {
    this.setAttempts(this.getAttempts() + 1)
  }

  showFinancials(event) {
    event.preventDefault()
    this.openFinancialStep(this.websiteInputTarget.value.trim())
  }

  startFromCta(event) {
    event.preventDefault()
    this.openFinancialStep(this.ctaWebsiteInputTarget.value.trim())
  }

  openFinancialStep(website) {
    this.clearError()

    if (!website) {
      this.showError("Please enter your company website.")
      return
    }

    if (!this.canRunSearch()) {
      this.showError("You’ve reached the free BuyerMap preview limit. Please book a call to continue.")
      return
    }

    this.recordAttempt()

    const name = this.extractCompanyName(website)

    this.websiteInputTarget.value = website
    this.websitePreviewTarget.textContent = website

    this.companyNameTargets.forEach((target) => {
      target.textContent = name
    })

    this.websiteStepTarget.classList.add("hidden")
    this.loadingStepTarget.classList.add("hidden")
    this.resultsStepTarget.classList.add("hidden")
    this.financialStepTarget.classList.remove("hidden")

    document.getElementById("buyer-map-tool")?.scrollIntoView({
      behavior: "smooth",
      block: "start"
    })
  }

  async startLoading(event) {
    event.preventDefault()
    this.clearError()

    const website = this.websiteInputTarget.value.trim()
    const revenueRange = this.hasRevenueRangeTarget ? this.revenueRangeTarget.value : ""
    const profitRange = this.hasProfitRangeTarget ? this.profitRangeTarget.value : ""

    this.financialStepTarget.classList.add("hidden")
    this.loadingStepTarget.classList.remove("hidden")

    // Kick off the real buyer match alongside the loading animation.
    this.requestSettled = false
    this.buyerData = null
    const requestPromise = this.requestBuyers({ website, revenueRange, profitRange })

    let progress = 0
    let messageIndex = 0

    this.progressBarTarget.style.width = "0%"
    this.progressTextTarget.textContent = "0%"

    const interval = setInterval(() => {
      const cap = this.requestSettled ? 100 : 92
      progress += Math.floor(Math.random() * 9) + 4
      if (progress >= cap) progress = cap

      this.progressBarTarget.style.width = `${progress}%`
      this.progressTextTarget.textContent = `${progress}%`

      const nextIndex = Math.min(
        Math.floor((progress / 100) * this.progressMessages.length),
        this.progressMessages.length - 1
      )

      if (nextIndex !== messageIndex) {
        messageIndex = nextIndex
        this.loadingTitleTarget.textContent = this.progressMessages[messageIndex][0]
        this.loadingDescriptionTarget.textContent = this.progressMessages[messageIndex][1]
      }

      if (progress === 100) {
        clearInterval(interval)

        setTimeout(() => {
          if (this.buyerData) this.populateResults(this.buyerData)
          this.loadingStepTarget.classList.add("hidden")
          this.resultsStepTarget.classList.remove("hidden")
        }, 700)
      }
    }, 400)

    try {
      this.buyerData = await requestPromise
      this.requestSettled = true
    } catch (error) {
      this.requestSettled = true
      clearInterval(interval)
      this.loadingStepTarget.classList.add("hidden")
      this.financialStepTarget.classList.remove("hidden")
      this.showError(error.message || "Something went wrong building your BuyerMap.")
    }
  }

  async requestBuyers({ website, revenueRange, profitRange }) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    const response = await fetch("/tools/find-buyers/analyze", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": token || ""
      },
      body: JSON.stringify({ website, revenue_range: revenueRange, profit_range: profitRange })
    })

    const data = await response.json().catch(() => ({}))
    if (!response.ok) {
      throw new Error(data.error || "We couldn't build your BuyerMap. Please try again.")
    }
    return data
  }

  populateResults(data) {
    const a = data.analysis || {}
    const b = data.buyers || {}

    if (this.hasBuyerCountTarget && b.buyer_count != null) {
      this.buyerCountTarget.textContent = b.buyer_count
    }
    if (this.hasAcquisitionsLastYearTarget && b.acquisitions_last_year != null) {
      this.acquisitionsLastYearTarget.textContent = b.acquisitions_last_year
    }
    if (this.hasMarketActivityTarget) {
      this.marketActivityTarget.textContent = b.market_activity || ""
    }
    if (this.hasBuyerAsOfTarget && b.as_of) {
      this.buyerAsOfTarget.textContent = b.as_of
    }

    this.companyNameTargets.forEach((t) => {
      if (a.company_name) t.textContent = a.company_name
    })

    this.renderCategories(b.categories || [])
    this.renderBuyers(b.buyers || [])
    this.renderSources(b.sources || [])
  }

  renderSources(sources) {
    if (!this.hasBuyerSourcesTarget) return

    this.buyerSourcesTarget.innerHTML = ""
    if (!sources.length) {
      this.buyerSourcesTarget.innerHTML = `<li class="text-slate-500">Buyer data is being compiled for your sector.</li>`
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
      this.buyerSourcesTarget.appendChild(li)
    })
  }

  renderCategories(categories) {
    if (!this.hasCategoriesTarget || !categories.length) return

    this.categoriesTarget.innerHTML = ""
    categories.forEach((category) => {
      const cell = document.createElement("div")
      cell.className = "rounded-sm border border-brand-100 bg-white p-5 text-center shadow-soft"
      cell.innerHTML = `
        <p class="font-serif text-3xl font-medium text-brand-900">${category.count}</p>
        <p class="mt-1 text-sm text-slate-600">${this.escapeHtml(category.label)}</p>
      `
      this.categoriesTarget.appendChild(cell)
    })
  }

  renderBuyers(buyers) {
    if (!this.hasBuyerCardsTarget || !buyers.length) return

    this.buyerCardsTarget.innerHTML = ""
    buyers.forEach((buyer) => {
      const card = document.createElement("div")
      card.className = "rounded-sm border border-brand-100 bg-white p-7 shadow-soft"
      const badge = buyer.acquisitions > 0
        ? `${this.escapeHtml(buyer.type_label || "Acquirer")} · ${buyer.acquisitions} acquisitions in 2025`
        : this.escapeHtml(buyer.type_label || "Active acquirer")
      card.innerHTML = `
        <div class="flex items-start justify-between gap-4">
          <h3 class="font-serif text-3xl font-medium text-brand-900">${this.escapeHtml(buyer.name)}</h3>
          <span class="shrink-0 rounded-full bg-brand-50 px-3 py-1 text-xs font-semibold text-brand-900">${badge}</span>
        </div>
        <p class="mt-1 text-sm text-slate-500">Backed By: ${this.escapeHtml(buyer.backed_by || "—")}</p>
        <p class="mt-4 text-base leading-7 text-slate-700">${this.escapeHtml(buyer.rationale)}</p>
      `
      this.buyerCardsTarget.appendChild(card)
    })
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

  escapeHtml(value) {
    const div = document.createElement("div")
    div.textContent = String(value)
    return div.innerHTML
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
      return "your business"
    }
  }
}

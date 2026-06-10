import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "websiteStep",
    "financialStep",
    "loadingStep",
    "reportStep",
    "dealCompsStep",
    "valueDriversStep",
    "businessValuationStep",
    "websiteInput",
    "companyName",
    "revenueInput",
    "profitInput",
    "salaryInput",
    "progressBar",
    "progressText",
    "loadingTitle",
    "loadingDescription",
    "stepList",
    "stepOneIndicator",
    "stepTwoIndicator",
    "stepThreeIndicator",
    "ctaWebsiteInput",
    "attemptCounter"
  ]

  connect() {
    this.messages = [
      ["Analyzing website", "Reviewing company signals and business model."],
      ["Checking market comps", "Comparing similar TMT transactions."],
      ["Reviewing value drivers", "Assessing margin, revenue quality, and growth profile."],
      ["Estimating valuation range", "Combining revenue, profit, and buyer demand signals."],
      ["Preparing report", "Building your preliminary valuation snapshot."]
    ]
    this.maxAttempts = 2
this.storageKey = "valuation_attempts"
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

    const website = this.websiteInputTarget.value.trim()

    if (!website) {
      alert("Please enter your company website.")
      return
    }

    if (!this.canRunSearch()) {
  alert("You’ve reached the free valuation preview limit. Please book a call to continue.")
  return
}

this.recordAttempt()
    this.companyNameTargets.forEach((target) => {
      target.textContent = this.extractCompanyName(website)
    })

    this.websiteStepTarget.classList.add("hidden")
    this.financialStepTarget.classList.remove("hidden")

    
  }

  startReport(event) {
    event.preventDefault()

    const revenue = Number(this.revenueInputTarget.value)
    const profit = Number(this.profitInputTarget.value)

    if (!revenue || !profit) {
      alert("Please enter your revenue and pre-tax profit.")
      return
    }

    if (profit > revenue) {
      alert("Pre-tax profit cannot be greater than annual revenue.")
      return
    }

    this.financialStepTarget.classList.add("hidden")
    this.loadingStepTarget.classList.remove("hidden")

    let progress = 0
    let messageIndex = -1

    this.stepListTarget.innerHTML = ""
    this.progressBarTarget.style.width = "0%"
    this.progressTextTarget.textContent = "0%"

    const interval = setInterval(() => {
      progress += Math.floor(Math.random() * 8) + 5
      if (progress >= 100) progress = 100

      this.progressBarTarget.style.width = `${progress}%`
      this.progressTextTarget.textContent = `${progress}%`

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
          this.loadingStepTarget.classList.add("hidden")
          this.reportStepTarget.classList.remove("hidden")
          this.showDealComps()
        }, 900)
      }
    }, 500)
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

  showDealComps(event) {
    if (event) event.preventDefault()

    this.dealCompsStepTarget.classList.remove("hidden")
    this.valueDriversStepTarget.classList.add("hidden")
    this.businessValuationStepTarget.classList.add("hidden")

    this.setActiveStep(1)
  }

  showValueDrivers(event) {
    if (event) event.preventDefault()

    this.dealCompsStepTarget.classList.add("hidden")
    this.valueDriversStepTarget.classList.remove("hidden")
    this.businessValuationStepTarget.classList.add("hidden")

    this.setActiveStep(2)
  }

  showBusinessValuation(event) {
    if (event) event.preventDefault()

    this.dealCompsStepTarget.classList.add("hidden")
    this.valueDriversStepTarget.classList.add("hidden")
    this.businessValuationStepTarget.classList.remove("hidden")

    this.setActiveStep(3)
  }

  setActiveStep(step) {
    const activeClass = "bg-brand-300 text-brand-900"
    const inactiveClass = "bg-slate-300 text-white"

    this.stepOneIndicatorTarget.className =
      `flex h-10 w-10 items-center justify-center rounded-full font-bold ${step === 1 ? activeClass : inactiveClass}`

    this.stepTwoIndicatorTarget.className =
      `flex h-10 w-10 items-center justify-center rounded-full font-bold ${step === 2 ? activeClass : inactiveClass}`

    this.stepThreeIndicatorTarget.className =
      `flex h-10 w-10 items-center justify-center rounded-full font-bold ${step === 3 ? activeClass : inactiveClass}`
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

  startFromCta(event) {
  event.preventDefault()

  const website = this.ctaWebsiteInputTarget.value.trim()

  if (!website) {
    alert("Please enter your company website.")
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

  document.getElementById("valuation-tool")?.scrollIntoView({
    behavior: "smooth",
    block: "start"
  })
}
}
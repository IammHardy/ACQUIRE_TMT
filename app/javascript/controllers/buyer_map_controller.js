import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "websiteStep",
    "financialStep",
    "loadingStep",
    "resultsStep",
    "detailsStep",
    "websiteInput",
    "ctaWebsiteInput",
    "websitePreview",
    "companyName",
    "progressBar",
    "progressText",
    "loadingTitle",
    "loadingDescription",
    "buyerCount",
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
    if (!website) {
      alert("Please enter your company website.")
      return
    }

    if (!this.canRunSearch()) {
  alert("You’ve reached the free BuyerMap preview limit. Please book a call to continue.")
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

  startLoading(event) {
    event.preventDefault()

    this.financialStepTarget.classList.add("hidden")
    this.loadingStepTarget.classList.remove("hidden")

    let progress = 0
    let messageIndex = 0

    this.progressBarTarget.style.width = "0%"
    this.progressTextTarget.textContent = "0%"

    const interval = setInterval(() => {
      progress += Math.floor(Math.random() * 9) + 4

      if (progress >= 100) {
        progress = 100
      }

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
          const simulatedCount = Math.floor(Math.random() * 176) + 425

          this.buyerCountTarget.textContent = simulatedCount
          this.loadingStepTarget.classList.add("hidden")
          this.resultsStepTarget.classList.remove("hidden")
        }, 700)
      }
    }, 400)
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
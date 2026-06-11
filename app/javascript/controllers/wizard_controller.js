import { Controller } from "@hotwired/stimulus"

// Client-side multi-step form. Shows one step at a time, drives the progress
// bar, and swaps Back/Next/Submit. Everything submits in one request at the end.
export default class extends Controller {
  static targets = ["step", "progress", "back", "next", "submit"]

  connect() {
    this.index = 0
    this.render()
  }

  next() {
    if (this.index < this.stepTargets.length - 1) {
      this.index++
      this.render()
    }
  }

  prev() {
    if (this.index > 0) {
      this.index--
      this.render()
    }
  }

  render() {
    this.stepTargets.forEach((step, i) => step.classList.toggle("hidden", i !== this.index))

    const pct = ((this.index + 1) / this.stepTargets.length) * 100
    if (this.hasProgressTarget) this.progressTarget.style.width = `${pct}%`

    const isLast = this.index === this.stepTargets.length - 1
    if (this.hasBackTarget) this.backTarget.classList.toggle("invisible", this.index === 0)
    if (this.hasNextTarget) this.nextTarget.classList.toggle("hidden", isLast)
    if (this.hasSubmitTarget) this.submitTarget.classList.toggle("hidden", !isLast)

    window.scrollTo({ top: 0, behavior: "smooth" })
  }
}

import { Controller } from "@hotwired/stimulus"

// Buyer-activity US map. Clicking a buyer in the list focuses that buyer's
// dots on the map (dims the rest); clicking again resets.
export default class extends Controller {
  static targets = ["group"]

  focus(event) {
    const id = event.currentTarget.dataset.buyer
    if (this.element.dataset.active === id) {
      this.reset()
      return
    }
    this.element.dataset.active = id
    this.groupTargets.forEach((group) => {
      group.style.opacity = group.dataset.buyer === id ? "1" : "0.1"
    })
    this.rows().forEach((row) => row.classList.toggle("bg-white", row.dataset.buyer === id))
  }

  reset() {
    delete this.element.dataset.active
    this.groupTargets.forEach((group) => { group.style.opacity = "1" })
    this.rows().forEach((row) => row.classList.remove("bg-white"))
  }

  rows() {
    return this.element.querySelectorAll("[data-usmap-row]")
  }
}

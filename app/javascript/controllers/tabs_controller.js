import { Controller } from "@hotwired/stimulus"

// Simple tabbed panels: each tab has data-tabs-index, each panel data-index.
export default class extends Controller {
  static targets = ["tab", "panel"]

  show(event) {
    const index = event.currentTarget.dataset.tabsIndex
    this.panelTargets.forEach((panel) => panel.classList.toggle("hidden", panel.dataset.index !== index))
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tabsIndex === index
      tab.classList.toggle("bg-brand-900", active)
      tab.classList.toggle("text-white", active)
      tab.classList.toggle("bg-brand-50", !active)
      tab.classList.toggle("text-brand-900", !active)
    })
  }
}

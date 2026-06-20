import { Controller } from "@hotwired/stimulus"

// Shows a dismissible cookie notice until the visitor accepts (stored locally).
export default class extends Controller {
  connect() {
    if (localStorage.getItem("cookie_consent") !== "accepted") {
      this.element.classList.remove("hidden")
    }
  }

  accept() {
    localStorage.setItem("cookie_consent", "accepted")
    this.element.remove()
  }
}

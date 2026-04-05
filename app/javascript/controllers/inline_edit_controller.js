import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form", "input"]

  edit() {
    this.displayTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    this.inputTarget.focus()
  }

  cancel() {
    this.formTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.cancel()
    }
  }
}

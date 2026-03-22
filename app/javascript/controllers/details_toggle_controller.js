import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["showLabel", "hideLabel"]

  connect() {
    this.update()
    this.element.addEventListener("toggle", this.update.bind(this))
  }

  update() {
    const open = this.element.open
    this.showLabelTarget.style.display = open ? "none" : "inline-flex"
    this.hideLabelTarget.style.display = open ? "inline-flex" : "none"
  }
}

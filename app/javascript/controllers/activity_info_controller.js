import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "overlayIcon", "overlayName", "overlayDesc", "iconTemplate"]

  show(event) {
    event.preventDefault()
    event.stopPropagation()

    const { name, desc, icon } = event.params
    this.overlayNameTarget.textContent = name
    this.overlayDescTarget.textContent = desc

    // Find matching icon template and inject its SVG
    const template = this.iconTemplateTargets.find(t => t.dataset.icon === icon)
    this.overlayIconTarget.innerHTML = template ? template.innerHTML : ""

    this.overlayTarget.classList.remove("hidden")
  }

  close(event) {
    event.preventDefault()
    this.overlayTarget.classList.add("hidden")
  }
}

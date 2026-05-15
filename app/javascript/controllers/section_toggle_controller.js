import { Controller } from "@hotwired/stimulus"

// Wraps a workout builder section in a collapsible `<details>` so editing
// large workouts is manageable — the summary shows just the section name,
// click to expand.
//
// - `display` target: the <span> in the summary that shows the section name.
//   Kept in sync with the inner name <input> via `syncDisplay`.
// - `chevron` target: the disclosure chevron — rotates when open/closed.
// - `stopBubble` action: for child elements (drag handle, delete button)
//   that live inside <summary> but must NOT trigger the open/close toggle.
export default class extends Controller {
  static targets = ["display", "chevron"]

  connect() {
    this.boundOnToggle = this.onToggle.bind(this)
    this.element.addEventListener("toggle", this.boundOnToggle)
    this.onToggle()
  }

  disconnect() {
    this.element.removeEventListener("toggle", this.boundOnToggle)
  }

  onToggle() {
    if (!this.hasChevronTarget) return
    this.chevronTarget.style.transform = this.element.open ? "rotate(180deg)" : "rotate(0deg)"
  }

  syncDisplay(event) {
    if (!this.hasDisplayTarget) return
    const value = event.target.value.trim()
    this.displayTarget.textContent = value || "Untitled section"
  }

  stopBubble(event) {
    event.stopPropagation()
  }
}

import { Controller } from "@hotwired/stimulus"

// Keeps session focus fields in sync with the selected sessions-per-week count.
// Also drives the weeks-count slider display.
export default class extends Controller {
  static targets = ["weeksDisplay", "weeksInput", "sessionRow", "pill", "customInput"]

  connect() {
    this.updateSessions()
  }

  updateWeeks() {
    if (this.hasWeeksDisplayTarget && this.hasWeeksInputTarget) {
      this.weeksDisplayTarget.textContent = this.weeksInputTarget.value
    }
  }

  updateSessions() {
    const selected = this.element.querySelector("input[name='program[sessions_per_week]']:checked")
    const count = selected ? parseInt(selected.value) : 3

    this.sessionRowTargets.forEach((row, i) => {
      row.classList.toggle("hidden", i >= count)
      if (i >= count) {
        const input = row.querySelector("input")
        if (input) input.value = ""
      }
    })
  }

  pillSelected() {
    if (this.hasCustomInputTarget) {
      this.customInputTarget.value = ""
      this.#toggleCustomBorder(false)
    }
  }

  customTyped() {
    if (!this.hasCustomInputTarget) return
    const hasText = this.customInputTarget.value.trim() !== ""
    if (hasText) {
      this.pillTargets.forEach(radio => radio.checked = false)
    }
    this.#toggleCustomBorder(hasText)
  }

  #toggleCustomBorder(active) {
    const input = this.customInputTarget
    if (active) {
      input.classList.remove("border-zinc-700")
      input.classList.add("border-lime-400", "bg-lime-400/5")
    } else {
      input.classList.remove("border-lime-400", "bg-lime-400/5")
      input.classList.add("border-zinc-700")
    }
  }
}

import { Controller } from "@hotwired/stimulus"

// Drives the new-program form:
//  * Reveals exactly N session-focus inputs based on the sessions-per-week pick
//  * Keeps the weeks-count slider readout in sync
//  * Pre-fills the session-focus inputs with the prescribed Hyrox weekly-shape
//    labels when Hyrox is the selected activity (and only for inputs the user
//    hasn't manually edited)
//  * Clears prefilled values when the user moves off Hyrox
export default class extends Controller {
  static targets = [
    "weeksDisplay", "weeksInput",
    "sessionsDisplay", "sessionsInput",
    "sessionRow", "pill", "customInput"
  ]
  static values = {
    // Race-family prefill labels — { "Hyrox": { "1": ["..."], "2": [...] },
    // "Deka Fit": { ... }, "Deka Atlas": { ... }, ... }. Stimulus looks up
    // labels by the currently-selected activity name.
    prefillLabels: Object
  }

  connect() {
    this.updateSessions()
    this.applyPrefill()
  }

  updateWeeks() {
    if (this.hasWeeksDisplayTarget && this.hasWeeksInputTarget) {
      this.weeksDisplayTarget.textContent = this.weeksInputTarget.value
    }
  }

  updateSessions() {
    const count = this.#selectedSessionCount()

    if (this.hasSessionsDisplayTarget) {
      this.sessionsDisplayTarget.textContent = count
    }

    this.sessionRowTargets.forEach((row, i) => {
      row.classList.toggle("hidden", i >= count)
      if (i >= count) {
        // Reset the focus text (first text input) when the row is hidden so
        // we don't submit stale entries from a higher previous count.
        const focusInput = row.querySelector("input[type='text']")
        if (focusInput) {
          focusInput.value = ""
          delete focusInput.dataset.prefilled
        }
      }
    })
    this.applyPrefill()
  }

  pillSelected() {
    if (this.hasCustomInputTarget) {
      this.customInputTarget.value = ""
      this.#toggleCustomBorder(false)
    }
    this.applyPrefill()
  }

  customTyped() {
    // While the user is typing we only update the visual border and clear
    // any selected pill — prefill is deferred until they click away (blur).
    if (!this.hasCustomInputTarget) return
    const hasText = this.customInputTarget.value.trim() !== ""
    if (hasText) {
      this.pillTargets.forEach(radio => radio.checked = false)
    }
    this.#toggleCustomBorder(hasText)
  }

  customBlurred() {
    // Apply prefill once the user has committed their typing (clicked away
    // or tabbed out). Avoids re-populating session focus fields on every
    // keystroke.
    this.applyPrefill()
  }

  // ---- prefill ----

  applyPrefill() {
    if (!this.hasPrefillLabelsValue) return

    const activity = this.#selectedActivityName()
    const activityLabels = this.prefillLabelsValue[activity]
    if (!activityLabels) {
      this.#clearPrefilledFields()
      return
    }

    const count = this.#selectedSessionCount()
    const labels = activityLabels[String(count)] || []
    this.sessionRowTargets.forEach((row, i) => {
      if (i >= count) return
      const input = row.querySelector("input")
      if (!input) return
      // Only fill fields that are empty or that we previously prefilled.
      if (input.value === "" || input.dataset.prefilled === "true") {
        input.value = labels[i] || ""
        input.dataset.prefilled = "true"
      }
    })
  }

  #clearPrefilledFields() {
    this.sessionRowTargets.forEach(row => {
      const input = row.querySelector("input")
      if (input && input.dataset.prefilled === "true") {
        input.value = ""
        delete input.dataset.prefilled
      }
    })
  }

  #selectedActivityName() {
    const customValue = this.hasCustomInputTarget ? this.customInputTarget.value.trim() : ""
    if (customValue) return customValue
    const selected = this.pillTargets.find(p => p.checked)
    return selected ? selected.value : ""
  }

  #selectedSessionCount() {
    if (this.hasSessionsInputTarget) return parseInt(this.sessionsInputTarget.value)
    const selected = this.element.querySelector("input[name='program[sessions_per_week]']:checked")
    return selected ? parseInt(selected.value) : 3
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

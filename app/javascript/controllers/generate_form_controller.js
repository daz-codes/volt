import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pill", "customInput", "submitBtn", "scanLabel"]

  customTyped() {
    const hasText = this.customInputTarget.value.trim() !== ""
    if (hasText) {
      this.pillTargets.forEach(radio => radio.checked = false)
    }
    this.#toggleCustomBorder(hasText)
  }

  pillSelected() {
    this.customInputTarget.value = ""
    this.#toggleCustomBorder(false)
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

  showSpinner(labelOrEvent = null) {
    const label = (typeof labelOrEvent === "string") ? labelOrEvent : "Generating workout\u2026"
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = true
      this.submitBtnTarget.innerHTML =
        '<span class="inline-flex items-center justify-center gap-2">' +
          '<svg class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">' +
            '<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>' +
            '<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>' +
          '</svg>' +
          label +
        '</span>'
    }
  }

  submitOnFileSelect(event) {
    const file = event.target.files[0]
    if (!file) return

    const MAX_SIZE = 5 * 1024 * 1024
    if (file.size > MAX_SIZE) {
      alert("Image must be under 5MB. Please choose a smaller file.")
      event.target.value = ""
      return
    }

    if (this.hasScanLabelTarget) {
      this.scanLabelTarget.innerHTML =
        '<span class="inline-flex items-center justify-center gap-2">' +
          '<svg class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">' +
            '<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>' +
            '<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>' +
          '</svg>' +
          'Scanning workout\u2026' +
        '</span>'
      this.scanLabelTarget.classList.add("border-lime-400", "bg-lime-400/5")
      this.scanLabelTarget.classList.remove("border-zinc-600")
    }

    this.showSpinner("Scanning workout\u2026")
    event.target.form.requestSubmit()
  }
}

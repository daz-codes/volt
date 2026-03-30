import { Controller } from "@hotwired/stimulus"

const SPINNER_HTML =
  '<div class="px-6 py-12 flex flex-col items-center justify-center gap-3">' +
    '<svg class="animate-spin h-8 w-8 text-lime-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">' +
      '<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>' +
      '<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>' +
    '</svg>' +
    '<p class="text-sm text-gray-400" data-dialog-target="spinnerLabel">Working\u2026</p>' +
  '</div>'

export default class extends Controller {
  static targets = ["chooser", "generateModal", "spinnerLabel"]

  open() {
    this.chooserTarget.showModal()
  }

  openGenerate() {
    this.chooserTarget.close()
    this.generateModalTarget.showModal()
  }

  close() {
    if (this.hasChooserTarget) this.chooserTarget.close()
    if (this.hasGenerateModalTarget) this.generateModalTarget.close()
  }

  // Close when clicking the backdrop (the dialog element itself, not its content)
  backdropClick(event) {
    if (event.target === this.chooserTarget || event.target === this.generateModalTarget) {
      event.target.close()
    }
  }

  // Called when the scan file input changes — validates, shows spinner, submits
  handleScan(event) {
    const file = event.target.files[0]
    if (!file) return

    const MAX_SIZE = 5 * 1024 * 1024
    if (file.size > MAX_SIZE) {
      alert("Image must be under 5MB. Please choose a smaller file.")
      event.target.value = ""
      return
    }

    this.#showChooserSpinner("Scanning workout\u2026")
    event.target.closest("form").requestSubmit()
  }

  #showChooserSpinner(label) {
    if (this.hasChooserTarget) {
      this.chooserTarget.innerHTML = SPINNER_HTML
      if (this.hasSpinnerLabelTarget) {
        this.spinnerLabelTarget.textContent = label
      }
    }
  }
}

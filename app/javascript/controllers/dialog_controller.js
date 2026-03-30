import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chooser", "generateModal"]

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
}

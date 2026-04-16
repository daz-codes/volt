import { Controller } from "@hotwired/stimulus"

const CM_PER_INCH = 2.54
const KG_PER_LB = 0.453592

export default class extends Controller {
  static targets = [
    "radio",
    "metricHeight", "imperialHeight",
    "metricWeight", "imperialWeight",
    "heightCm", "heightFt", "heightIn",
    "weightKg", "weightLbs"
  ]

  // Switch visible fields when the radio changes
  switch(event) {
    const system = event.target.value
    const imperial = system === "imperial"

    this.metricHeightTarget.hidden = imperial
    this.imperialHeightTarget.hidden = !imperial
    this.metricWeightTarget.hidden = imperial
    this.imperialWeightTarget.hidden = !imperial
  }

  // Before the form submits, if imperial is active, convert values
  // into the hidden metric inputs so the server receives cm/kg.
  // NOTE: This handler MUST stay synchronous — Turbo collects form data
  // immediately after the submit event, so any async work here would miss the window.
  beforeSubmit(_event) {
    const selected = this.radioTargets.find(r => r.checked)
    if (!selected || selected.value !== "imperial") return

    const ft = parseInt(this.heightFtTarget.value, 10)
    const inches = parseInt(this.heightInTarget.value, 10) || 0
    if (!isNaN(ft)) {
      const cm = Math.round((ft * 12 + inches) * CM_PER_INCH)
      this.heightCmTarget.value = cm
    } else {
      this.heightCmTarget.value = ""
    }

    const lbs = parseFloat(this.weightLbsTarget.value)
    if (!isNaN(lbs)) {
      const kg = Math.round(lbs * KG_PER_LB * 10) / 10
      this.weightKgTarget.value = kg
    } else {
      this.weightKgTarget.value = ""
    }
  }
}

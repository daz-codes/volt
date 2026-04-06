import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dot", "downBtn", "upBtn"]
  static values = { level: Number, workoutId: Number }

  levelValueChanged() {
    this.updateUI()
    // Update hidden field in post dialog (outside the Turbo Frame)
    const externalField = document.querySelector(
      `#complete_workout_${this.workoutIdValue} input[name="difficulty_level"]`
    )
    if (externalField) externalField.value = this.levelValue
  }

  updateUI() {
    const level = this.levelValue

    this.dotTargets.forEach((dot, i) => {
      if (i < level) {
        dot.classList.remove("bg-zinc-600")
        dot.classList.add("bg-volt")
      } else {
        dot.classList.remove("bg-volt")
        dot.classList.add("bg-zinc-600")
      }
    })

    if (this.hasDownBtnTarget) {
      this.downBtnTarget.disabled = level <= 1
      this.downBtnTarget.classList.toggle("opacity-40", level <= 1)
      this.downBtnTarget.classList.toggle("cursor-not-allowed", level <= 1)
    }

    if (this.hasUpBtnTarget) {
      this.upBtnTarget.disabled = level >= 5
      this.upBtnTarget.classList.toggle("opacity-40", level >= 5)
      this.upBtnTarget.classList.toggle("cursor-not-allowed", level >= 5)
    }
  }
}

import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Makes the workout builder section list drag-reorderable.
// Re-indexes section field names to sequential 0..N on form submit so that
// Workout::StructureBuilder#structure_from_params (which sorts by integer key)
// returns sections in the user's drag order.
export default class extends Controller {
  connect() {
    this.sortable = Sortable.create(this.element, {
      handle: "[data-sortable-handle]",
      animation: 150,
      ghostClass: "opacity-40",
      chosenClass: "ring-2"
    })

    this.form = this.element.closest("form")
    this.reindexBound = this.reindex.bind(this)
    this.form?.addEventListener("submit", this.reindexBound)
  }

  disconnect() {
    this.sortable?.destroy()
    this.sortable = null
    this.form?.removeEventListener("submit", this.reindexBound)
    this.form = null
  }

  reindex() {
    const sections = this.element.querySelectorAll("[data-section-id]")
    sections.forEach((section, i) => {
      const oldId = section.dataset.sectionId
      if (String(oldId) === String(i)) return
      section.dataset.sectionId = i
      section.querySelectorAll("[name]").forEach(el => {
        el.name = el.name.replace(`sections[${oldId}]`, `sections[${i}]`)
      })
    })
  }
}

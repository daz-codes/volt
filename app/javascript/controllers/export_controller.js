import { Controller } from "@hotwired/stimulus"

// Handles file export (image/PDF) without navigating away from the page.
// Uses Web Share API on mobile for native "Save to Photos" / share sheet,
// falls back to a hidden download link on desktop.
export default class extends Controller {
  static values = { url: String, filename: String, type: String }

  async export(event) {
    event.preventDefault()

    const btn = event.currentTarget
    const original = btn.innerHTML
    btn.style.pointerEvents = "none"
    btn.style.opacity = "0.5"

    try {
      const response = await fetch(this.urlValue)
      if (!response.ok) throw new Error("Download failed")

      const blob = await response.blob()
      const file = new File([blob], this.filenameValue, { type: this.typeValue })

      if (navigator.canShare?.({ files: [file] })) {
        await navigator.share({ files: [file] })
      } else {
        const url = URL.createObjectURL(blob)
        const a = document.createElement("a")
        a.href = url
        a.download = this.filenameValue
        document.body.appendChild(a)
        a.click()
        a.remove()
        URL.revokeObjectURL(url)
      }
      this.element.closest("dialog")?.close()
    } catch (err) {
      if (err.name !== "AbortError") {
        console.error("Export failed:", err)
      }
    } finally {
      btn.style.pointerEvents = ""
      btn.style.opacity = ""
    }
  }
}

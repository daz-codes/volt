import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "recipientId"]

  search() {
    const query = this.inputTarget.value.trim()
    if (query.length < 2) {
      this.resultsTarget.innerHTML = ""
      return
    }

    clearTimeout(this._timer)
    this._timer = setTimeout(() => {
      fetch(`/shares/search_users?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "text/html" }
      })
        .then(r => r.text())
        .then(html => { this.resultsTarget.innerHTML = html })
    }, 300)
  }

  select(event) {
    const userId = event.currentTarget.dataset.userId
    const userName = event.currentTarget.dataset.userName
    this.recipientIdTarget.value = userId
    this.inputTarget.value = userName
    this.resultsTarget.innerHTML = ""
  }
}

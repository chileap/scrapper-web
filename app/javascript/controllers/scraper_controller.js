import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "fieldsContainer", "result", "resultContent", "screenshotContainer", "screenshot", "screenshotLink"]
  static values = {
    url: String
  }

  connect() {
    console.log("Scraper controller connected")
  }

  addField(event) {
    event.preventDefault()
    const fieldRow = document.createElement('div')
    fieldRow.className = 'field-row mb-2'
    fieldRow.innerHTML = `
      <div class="row">
        <div class="col-md-5">
          <input type="text" class="form-control" placeholder="Field Name"
                 name="fields[][name]" aria-label="Field name">
        </div>
        <div class="col-md-6">
          <input type="text" class="form-control" placeholder="CSS Selector"
                 name="fields[][selector]" aria-label="CSS selector">
        </div>
        <div class="col-md-1">
          <button type="button" class="btn btn-danger" data-action="click->scraper#removeField" aria-label="Remove field">×</button>
        </div>
      </div>
    `
    this.fieldsContainerTarget.appendChild(fieldRow)
  }

  removeField(event) {
    event.preventDefault()
    event.target.closest('.field-row').remove()
  }

  async submit(event) {
    event.preventDefault()

    const url = this.formTarget.querySelector('#url').value
    const fields = {}

    this.formTarget.querySelectorAll('.field-row').forEach(row => {
      const nameInput = row.querySelector('input[placeholder="Field Name"]')
      const selectorInput = row.querySelector('input[placeholder="CSS Selector"]')
      if (nameInput.value && selectorInput.value) {
        fields[nameInput.value] = selectorInput.value
      }
    })

    const submitButton = this.formTarget.querySelector('button[type="submit"]')
    const originalButtonText = submitButton.textContent
    submitButton.disabled = true
    submitButton.textContent = 'Scraping...'

    try {
      const response = await fetch('/data.json', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ url, fields })
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()
      this.resultContentTarget.textContent = JSON.stringify(data, null, 2)
      this.resultTarget.style.display = 'block'

      if (data.screenshot) {
        this.screenshotTarget.src = data.screenshot
        this.screenshotLinkTarget.href = data.screenshot
        this.screenshotContainerTarget.style.display = 'block'
      } else {
        this.screenshotContainerTarget.style.display = 'none'
      }
    } catch (error) {
      this.resultContentTarget.textContent = `Error: ${error.message}`
      this.resultTarget.style.display = 'block'
    } finally {
      submitButton.disabled = false
      submitButton.textContent = originalButtonText
    }
  }
}
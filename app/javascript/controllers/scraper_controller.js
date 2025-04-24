import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "fieldsContainer", "result", "resultContent", "screenshotContainer", "screenshot", "screenshotLink"]
  static values = {
    url: String
  }

  connect() {
    console.log("Scraper controller connected")
    // Add event listeners for field type changes
    this.fieldsContainerTarget.addEventListener('change', (event) => {
      if (event.target.matches('select[name="fields[][type]"]')) {
        this.handleFieldTypeChange(event.target)
      }
    })
  }

  handleFieldTypeChange(selectElement) {
    const row = selectElement.closest('.field-row')
    const selectorInput = row.querySelector('.selector-input')
    const metaInput = row.querySelector('.meta-input')

    if (selectElement.value === 'meta') {
      selectorInput.style.display = 'none'
      metaInput.style.display = 'block'
    } else {
      selectorInput.style.display = 'block'
      metaInput.style.display = 'none'
    }
  }

  addField(event) {
    event.preventDefault()
    const fieldRow = document.createElement('div')
    fieldRow.className = 'field-row mb-2'
    fieldRow.innerHTML = `
      <div class="row">
        <div class="col-md-12 mb-4">
          <select class="form-select" name="fields[][type]" aria-label="Field type">
            <option value="selector" selected>CSS Selector</option>
            <option value="meta">Meta Tag</option>
          </select>
        </div>
        <div class="col-md-5">
          <input type="text" class="form-control" placeholder="Field Name"
                 name="fields[][name]" aria-label="Field name">
        </div>
        <div class="col-md-5 selector-input">
          <input type="text" class="form-control" placeholder="CSS Selector"
                 name="fields[][selector]" aria-label="CSS selector">
        </div>
        <div class="col-md-5 meta-input" style="display: none;">
          <div class="meta-tags-container">
            <div class="meta-tag-row mb-2">
              <div class="input-group">
                <input type="text" class="form-control" placeholder="Meta Tag Name"
                       name="fields[][meta_names][]" aria-label="Meta tag name">
                <button type="button" class="btn btn-outline-danger" data-action="click->scraper#removeMetaTag">×</button>
              </div>
            </div>
          </div>
          <button type="button" class="btn btn-sm btn-outline-secondary mt-2" data-action="click->scraper#addMetaTag">Add Meta Tag</button>
        </div>
        <div class="col-md-2 ml-auto">
          <button type="button" class="btn btn-danger w-100 text-center" data-action="click->scraper#removeField" aria-label="Remove field">×</button>
        </div>
      </div>
    `
    this.fieldsContainerTarget.appendChild(fieldRow)
  }

  addMetaTag(event) {
    event.preventDefault()
    const container = event.target.previousElementSibling
    const metaTagRow = document.createElement('div')
    metaTagRow.className = 'meta-tag-row mb-2'
    metaTagRow.innerHTML = `
      <div class="input-group">
        <input type="text" class="form-control" placeholder="Meta Tag Name"
               name="fields[][meta_names][]" aria-label="Meta tag name">
        <button type="button" class="btn btn-outline-danger" data-action="click->scraper#removeMetaTag">×</button>
      </div>
    `
    container.appendChild(metaTagRow)
  }

  removeMetaTag(event) {
    event.preventDefault()
    const metaTagRow = event.target.closest('.meta-tag-row')
    metaTagRow.remove()
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
      const typeSelect = row.querySelector('select[name="fields[][type]"]')
      const nameInput = row.querySelector('input[placeholder="Field Name"]')

      if (!typeSelect || !nameInput) return

      if (typeSelect.value === 'meta') {
        const metaNames = Array.from(row.querySelectorAll('input[name="fields[][meta_names][]"]'))
          .map(input => input.value)
          .filter(value => value.trim() !== '')

        if (metaNames.length > 0) {
          fields.meta = metaNames
        }
      } else {
        const selectorInput = row.querySelector('input[placeholder="CSS Selector"]')
        if (nameInput.value && selectorInput.value) {
          fields[nameInput.value] = selectorInput.value
        }
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

  async clearCache(event) {
    event.preventDefault()

    const url = this.formTarget.querySelector('#url').value

    if (!confirm('Are you sure you want to clear the cache for this URL?')) {
      return
    }

    const response = await fetch('/web_scraper/clear_cache', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ url })
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    const data = await response.json();
    if (data.status === 'success') {
      this.showNotification('Cache cleared successfully', 'success')
    } else {
      this.showNotification('Failed to clear cache', 'error')
    }
  }

  showNotification(message, type = 'info') {
    // You can implement a toast notification system here
    alert(message) // TODO: Implement a toast notification system
  }
}
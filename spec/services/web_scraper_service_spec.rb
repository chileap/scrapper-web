require 'rails_helper'

RSpec.describe WebScraperService do
  let(:url) { 'https://example.com' }
  let(:fields) { { title: 'h1', content: '.content' } }

  describe '#scrape' do
    it 'uses cached results when available' do
      # Mock the cache service
      cache_service = instance_double('WebScraperCacheService')
      allow(WebScraperCacheService).to receive(:new).and_return(cache_service)

      # Set up cache behavior - first call returns nil, second call returns cached result
      allow(cache_service).to receive(:get_cached_result).with(url)
        .and_return(nil, { 'html' => '<html><body><h1>Cached Title</h1><div class="content">Cached Content</div></body></html>', 'screenshot' => '/screenshots/example.png' })
      allow(cache_service).to receive(:cache_result)

      service = described_class.new

      # Create a proper session double with driver
      session_double = double('session')
      driver_double = double('driver')
      browser_double = double('browser')

      # Set up session double expectations
      allow(session_double).to receive(:driver).and_return(driver_double)
      allow(driver_double).to receive(:quit)
      allow(driver_double).to receive(:browser).and_return(browser_double)
      allow(browser_double).to receive(:execute_script).and_return(true)
      allow(session_double).to receive(:html).and_return('<html><body><h1>Cached Title</h1><div class="content">Cached Content</div></body></html>')
      allow(session_double).to receive(:save_screenshot).and_return(true)
      allow(session_double).to receive(:evaluate_script).with('document.readyState').and_return('complete')
      allow(session_double).to receive(:visit)
      allow(session_double).to receive(:find).and_return(double('element', text: 'Cached Title'))

      # First scrape (should not use cache)
      allow(service).to receive(:create_session).and_return(session_double)
      allow(service).to receive(:navigate_to_url)
      allow(service).to receive(:capture_screenshot).and_return('/screenshots/example.png')
      allow(service).to receive(:extract_fields).and_return({ title: 'Cached Title', content: 'Cached Content' })

      # Perform first scrape
      first_result = service.scrape(url, fields)

      # Reset create_session count for the second scrape
      allow(service).to receive(:create_session).and_return(session_double)

      # Perform second scrape (should use cache)
      second_result = service.scrape(url, fields)

      # Verify results
      expect(second_result).to eq(first_result)
      expect(service).to have_received(:create_session).twice # Once for initial scrape, once for loading cached content
      expect(cache_service).to have_received(:get_cached_result).twice
      expect(cache_service).to have_received(:cache_result).once
    end
  end
end
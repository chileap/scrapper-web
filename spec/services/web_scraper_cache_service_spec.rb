require 'rails_helper'

RSpec.describe WebScraperCacheService do
  let(:service) { described_class.new }
  let(:url) { 'https://example.com' }
  let(:session) { double('session') }
  let(:screenshot_path) { Rails.root.join('public', 'screenshots', "#{Digest::MD5.hexdigest(url)}_#{Time.now.to_i}.png") }
  let(:cached_content) do
    {
      html: '<html><body><h1>Example Title</h1><div class="content">Example Content</div></body></html>',
      url: url,
      timestamp: Time.now.to_i,
      screenshot: '/screenshots/example.png'
    }
  end

  before do
    allow(session).to receive(:html).and_return(cached_content[:html])
    allow(session).to receive(:save_screenshot).and_return(true)
    # Allow any file existence check to return true
    allow(File).to receive(:exist?).and_return(true)
  end

  describe '#cache_result and #get_cached_result' do
    it 'caches and retrieves results correctly' do
      # Cache the result
      service.cache_result(url, session)

      # Retrieve the cached result
      cached_result = service.get_cached_result(url)

      expect(cached_result).to include(
        'html' => cached_content[:html],
        'url' => url
      )
      expect(cached_result['screenshot']).to match(%r{^/screenshots/[a-f0-9]+_\d+\.png$})
      expect(cached_result['timestamp']).to be_a(Integer)
    end

    it 'returns nil for non-existent cache entries' do
      cached_result = service.get_cached_result('https://nonexistent.com')
      expect(cached_result).to be_nil
    end
  end

  describe '#clear_cache' do
    it 'clears cache for a specific URL' do
      # Cache results for two different URLs
      service.cache_result(url, session)
      service.cache_result('https://another.com', session)

      # Clear cache for the first URL
      service.clear_cache(url)

      # First URL's cache should be cleared
      expect(service.get_cached_result(url)).to be_nil
      # Second URL's cache should still exist
      expect(service.get_cached_result('https://another.com')).to be_present
    end

    it 'clears all cache when no URL is specified' do
      # Cache results for two different URLs
      service.cache_result(url, session)
      service.cache_result('https://another.com', session)

      # Clear all cache
      service.clear_cache

      # Both caches should be cleared
      expect(service.get_cached_result(url)).to be_nil
      expect(service.get_cached_result('https://another.com')).to be_nil
    end
  end
end
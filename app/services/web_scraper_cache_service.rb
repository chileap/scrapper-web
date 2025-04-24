require 'redis'

class WebScraperCacheService
  CACHE_PREFIX = 'web_scraper'
  CACHE_EXPIRATION = 1.hour

  def initialize
    @redis = Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379')
  end

  def get_cached_result(url)
    return nil unless valid_url?(url)

    key = cache_key(url)
    cached_data = @redis.get(key)

    if cached_data
      Rails.logger.info "Cache hit for URL: #{url} (key: #{key})"
      begin
        JSON.parse(cached_data)
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse cached data for #{url}: #{e.message}"
        nil
      end
    else
      Rails.logger.info "Cache miss for URL: #{url} (key: #{key})"
      nil
    end
  end

  def cache_result(url, session)
    return nil unless valid_url?(url)

    key = cache_key(url)
    page_content = {
      html: session.html,
      url: url,
      timestamp: Time.now.to_i,
      screenshot: capture_screenshot(session, url)
    }

    @redis.setex(key, CACHE_EXPIRATION, page_content.to_json)
    Rails.logger.info "Cached content for URL: #{url} (key: #{key})"
  end

  def clear_cache(url = nil)
    if url
      return nil unless valid_url?(url)
      key = cache_key(url)
      @redis.del(key)
      Rails.logger.info "Cleared cache for URL: #{url} (key: #{key})"
    else
      pattern = "#{CACHE_PREFIX}:*"
      keys = @redis.keys(pattern)
      if keys.any?
        @redis.del(*keys)
        Rails.logger.info "Cleared all cache keys matching pattern: #{pattern}"
      end
    end
  end

  def cache_stats
    pattern = "#{CACHE_PREFIX}:*"
    keys = @redis.keys(pattern)
    {
      total_keys: keys.size,
      keys: keys.map { |k| k.gsub("#{CACHE_PREFIX}:", '') }
    }
  end

  private

  def valid_url?(url)
    if url.nil? || url.to_s.strip.empty?
      Rails.logger.error "Invalid URL: URL cannot be nil or empty"
      return false
    end

    begin
      URI.parse(url)
      true
    rescue URI::InvalidURIError => e
      Rails.logger.error "Invalid URL format: #{url} - #{e.message}"
      false
    end
  end

  def cache_key(url)
    "#{CACHE_PREFIX}:#{Digest::MD5.hexdigest(url.to_s)}"
  end

  def capture_screenshot(session, url)
    return nil unless valid_url?(url)

    filename = "#{Digest::MD5.hexdigest(url.to_s)}_#{Time.now.to_i}.png"
    screenshot_path = Rails.root.join('public', 'screenshots', filename)

    begin
      session.save_screenshot(screenshot_path)
      return "/screenshots/#{filename}" if File.exist?(screenshot_path)
    rescue => e
      Rails.logger.error "Error taking screenshot: #{e.message}"
    end

    nil
  end
end
require 'selenium-webdriver'
require 'capybara'
require 'fileutils'
require 'digest'

module WebScraperConfig
  USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.59'
  ].freeze

  CHROME_OPTIONS = {
    headless: '--headless=new',
    disable_gpu: '--disable-gpu',
    no_sandbox: '--no-sandbox',
    disable_dev_shm: '--disable-dev-shm-usage',
    window_size: '--window-size=1920,1080'
  }.freeze

  TIMEOUTS = {
    page_load: 30,
    element_wait: 10,
    meta_wait: 5
  }.freeze

  DELAY_RANGE = (3..10).freeze
end

class WebScraperService
  include WebScraperConfig

  # Initializes a new WebScraperService instance
  # Sets up Capybara and creates the screenshots directory
  def initialize
    setup_capybara
    setup_screenshots_directory
    @cache_service = WebScraperCacheService.new
  end

  # Scrapes content from a given URL based on specified fields
  # @param url [String] The URL to scrape
  # @param fields [Hash] A hash of field names and their corresponding selectors
  # @return [Hash] A hash containing the scraped data and screenshot path
  def scrape(url, fields)
    # Try to get cached result first
    cached_result = @cache_service.get_cached_result(url)
    if cached_result
      Rails.logger.info "Using cached content for URL: #{url}"
      # Create a new session and load the cached HTML
      session = create_session
      begin
        # Properly escape the HTML content
        escaped_html = cached_result['html'].gsub(/'/, "\\\\'").gsub(/\n/, '\\n')

        # Use a more reliable method to set the HTML content
        session.driver.browser.execute_script(<<~JS)
          document.open();
          document.write('#{escaped_html}');
          document.close();
        JS

        wait_for_page_load(session)

        # Extract requested fields from cached content
        result = extract_fields(session, fields, from_cache: true)
        result[:screenshot] = cached_result['screenshot'] if cached_result['screenshot']
        return result
      rescue => e
        Rails.logger.error "Error loading cached content: #{e.message}"
        # If there's an error loading cached content, fall back to scraping
      ensure
        cleanup_session(session)
      end
    end

    Rails.logger.info "Scraping fresh content for URL: #{url}"
    # If not in cache or error loading cache, scrape the page
    session = create_session
    result = {}

    begin
      navigate_to_url(session, url)

      # Extract all fields from the page
      scraped_data = extract_fields(session, fields)

      # Add screenshot to result
      result[:screenshot] = capture_screenshot(session, url)

      # Merge scraped data with result
      result.merge!(scraped_data)

      # Cache the complete result
      @cache_service.cache_result(url, session)
    ensure
      cleanup_session(session)
    end

    result
  end

  def clear_cache(url = nil)
    @cache_service.clear_cache(url)
  end

  private

  def create_session
    Capybara::Session.new(:selenium_chrome_headless)
  end

  def cleanup_session(session)
    session.driver.quit
  end

  def navigate_to_url(session, url)
    random_delay
    session.visit(url)
    wait_for_page_load(session)
  end

  def extract_fields(session, fields, from_cache: false)
    fields.each_with_object({}) do |(field_name, selector), result|
      random_delay unless from_cache
      result[field_name] = field_name == 'meta' ?
        extract_meta_tags(session, selector) :
        extract_content(session, selector)
    end
  end

  def random_delay
    delay = rand(DELAY_RANGE)
    Rails.logger.info "Waiting for #{delay} seconds..."
    sleep(delay)
  end

  def setup_capybara
    Capybara.register_driver :selenium_chrome_headless do |app|
      options = configure_chrome_options
      Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
    end

    Capybara.javascript_driver = :selenium_chrome_headless
    Capybara.default_driver = :selenium_chrome_headless
  end

  def configure_chrome_options
    options = Selenium::WebDriver::Chrome::Options.new
    CHROME_OPTIONS.each { |_, arg| options.add_argument(arg) }
    options.add_argument("--user-agent=#{USER_AGENTS.sample}")
    options
  end

  def setup_screenshots_directory
    @screenshots_dir = Rails.root.join('public', 'screenshots')
    FileUtils.mkdir_p(@screenshots_dir)
  end

  def capture_screenshot(session, url)
    filename = generate_screenshot_filename(url)
    screenshot_path = @screenshots_dir.join(filename)

    begin
      session.save_screenshot(screenshot_path)
      return "/screenshots/#{filename}" if File.exist?(screenshot_path)
      Rails.logger.error "Failed to create screenshot at #{screenshot_path}"
    rescue => e
      Rails.logger.error "Error taking screenshot: #{e.message}"
    end

    nil
  end

  def generate_screenshot_filename(url)
    "#{Digest::MD5.hexdigest(url)}_#{Time.now.to_i}.png"
  end

  def wait_for_page_load(session)
    Timeout.timeout(TIMEOUTS[:page_load]) do
      loop until session.evaluate_script('document.readyState') == 'complete'
    end
  rescue Timeout::Error
    raise "Page load timeout exceeded"
  end

  def extract_content(session, selector)
    begin
      element = session.find(selector, match: :first, wait: TIMEOUTS[:element_wait])
      element.text.strip
    rescue Capybara::Ambiguous
      handle_multiple_elements(session, selector)
    rescue Capybara::ElementNotFound
      nil
    end
  end

  def handle_multiple_elements(session, selector)
    elements = session.all(selector, wait: TIMEOUTS[:element_wait])
    elements.map(&:text).map(&:strip).join(' ')
  end

  def extract_meta_tags(session, meta_names)
    meta_names.each_with_object({}) do |meta_name, result|
      result[meta_name] = find_meta_tag_content(session, meta_name)
    end
  end

  def find_meta_tag_content(session, meta_name)
    meta_tag = find_meta_tag_by_attribute(session, meta_name, 'name') ||
               find_meta_tag_by_attribute(session, meta_name, 'property') ||
               find_meta_tag_by_content(session, meta_name)

    meta_tag&.[]('content')
  end

  def find_meta_tag_by_attribute(session, meta_name, attribute)
    session.find("meta[#{attribute}='#{meta_name}']",
                match: :first,
                wait: TIMEOUTS[:meta_wait],
                visible: false) rescue nil
  end

  def find_meta_tag_by_content(session, meta_name)
    session.find("meta[content*='#{meta_name}']",
                match: :first,
                wait: TIMEOUTS[:meta_wait],
                visible: false) rescue nil
  end
end

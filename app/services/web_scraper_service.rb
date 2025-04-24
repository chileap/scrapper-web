require 'selenium-webdriver'
require 'capybara'
require 'fileutils'
require 'digest'

class WebScraperService
  USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.59'
  ].freeze

  def initialize
    setup_capybara
    setup_screenshots_directory
  end

  def scrape(url, fields)
    session = Capybara::Session.new(:selenium_chrome_headless)

    begin
      # Add random delay before visiting the URL
      random_delay
      session.visit(url)
      wait_for_page_load(session)

      # Take screenshot before extracting content
      screenshot_path = take_screenshot(session, url)

      result = {}
      fields.each do |field_name, selector|
        # Add random delay before each field extraction
        random_delay
        result[field_name] = extract_content(session, selector)
      end

      # Only include screenshot path if it was successfully created
      if screenshot_path && File.exist?(Rails.root.join('public', screenshot_path))
        result[:screenshot] = screenshot_path
      end

      result
    ensure
      session.driver.quit
    end
  end

  private

  def random_delay
    # Generate a random delay between 3 and 10 seconds
    delay = rand(3..10)
    Rails.logger.info "Waiting for #{delay} seconds..."
    sleep(delay)
  end

  def setup_capybara
    Capybara.register_driver :selenium_chrome_headless do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless=new')
      options.add_argument('--disable-gpu')
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
      options.add_argument('--window-size=1920,1080')
      options.add_argument("--user-agent=#{USER_AGENTS.sample}")

      Capybara::Selenium::Driver.new(
        app,
        browser: :chrome,
        options: options
      )
    end

    Capybara.javascript_driver = :selenium_chrome_headless
    Capybara.default_driver = :selenium_chrome_headless
  end

  def setup_screenshots_directory
    @screenshots_dir = Rails.root.join('public', 'screenshots')
    FileUtils.mkdir_p(@screenshots_dir)
  end

  def take_screenshot(session, url)
    begin
      # Generate a unique filename based on the URL and timestamp
      filename = "#{Digest::MD5.hexdigest(url)}_#{Time.now.to_i}.png"
      screenshot_path = @screenshots_dir.join(filename)

      # Take the screenshot
      session.save_screenshot(screenshot_path)

      # Verify the screenshot was created
      if File.exist?(screenshot_path)
        # Return the relative path for the response
        "/screenshots/#{filename}"
      else
        Rails.logger.error "Failed to create screenshot at #{screenshot_path}"
        nil
      end
    rescue => e
      Rails.logger.error "Error taking screenshot: #{e.message}"
      nil
    end
  end

  def wait_for_page_load(session)
    Timeout.timeout(30) do
      loop until session.evaluate_script('document.readyState') == 'complete'
    end
  rescue Timeout::Error
    raise "Page load timeout exceeded"
  end

  def extract_content(session, selector)
    # First try to find a single element
    begin
      element = session.find(selector, match: :first, wait: 10)
      return element.text.strip
    rescue Capybara::Ambiguous
      # If multiple elements found, get all of them and join their text
      elements = session.all(selector, wait: 10)
      return elements.map(&:text).map(&:strip).join(' ')
    rescue Capybara::ElementNotFound
      nil
    end
  end
end

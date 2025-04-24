class WebScraperController < ApplicationController
  def clear_cache
    url = params[:url]
    WebScraperService.new.clear_cache(url)

    respond_to do |format|
      format.html { redirect_to scrape_web_scraper_path(url: url), notice: 'Cache cleared successfully' }
      format.json { render json: { status: 'success', message: 'Cache cleared successfully' } }
    end
  end
end
class DataController < ApplicationController
  def index
    respond_to do |format|
      format.html
      format.json do
        # For POST requests, use the request parameters directly
        # For GET requests, parse the body if present
        params = if request.post?
          request.parameters
        else
          request_body = request.body.read
          request_body.present? ? JSON.parse(request_body) : {}
        end

        url = params['url']
        fields = params['fields']

        if url.blank? || fields.blank?
          render json: { error: "URL and fields are required" }, status: :bad_request
          return
        end

        scraper = WebScraperService.new
        result = scraper.scrape(url, fields)

        render json: result
      end
    end
  rescue JSON::ParserError => e
    render json: { error: "Invalid JSON format" }, status: :bad_request
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to root_path, alert: e.message }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end
end
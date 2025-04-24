# Scraping Data Testing Application

This is a Ruby on Rails application designed for testing web scraping functionality. The application is containerized using Docker for easy deployment and development.

## System Requirements

* Ruby 3.2.2
* PostgreSQL
* Docker (optional)

## Technology Stack

* Ruby on Rails 7.1.5
* PostgreSQL Database
* Puma Web Server
* Hotwire (Turbo & Stimulus)
* Import Maps for JavaScript
* Sprockets for Asset Pipeline

## Getting Started

### Local Development Setup

1. Clone the repository:
   ```bash
   git clone [repository-url]
   cd scrapping-data-testing
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Database setup:
   ```bash
   rails db:create
   rails db:migrate
   ```

4. Start the Rails server:
   ```bash
   rails server
   ```

### Docker Setup

1. Build the Docker image:
   ```bash
   docker build -t scraping-app .
   ```

2. Run the container:
   ```bash
   docker compose up
   ```

## Development

* The application uses standard Rails conventions
* JavaScript is handled through Import Maps
* Hotwire (Turbo and Stimulus) is available for enhanced interactivity

## Testing

Run the test suite with:
```bash
rails test
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

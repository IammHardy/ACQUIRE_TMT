// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Show the top progress bar sooner during page navigations (default is 500ms).
if (window.Turbo?.config?.drive) {
  window.Turbo.config.drive.progressBarDelay = 150
}

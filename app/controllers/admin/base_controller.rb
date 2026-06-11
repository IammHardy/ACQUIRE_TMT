class Admin::BaseController < ApplicationController
  before_action :authenticate_admin

  private

  INSECURE_DEFAULT_PASSWORD = "change-me-in-production".freeze

  # Simple HTTP Basic auth for the single-operator admin area.
  # Set ADMIN_USERNAME / ADMIN_PASSWORD in the environment (.env locally,
  # Kamal secrets in production).
  def authenticate_admin
    expected_user = ENV["ADMIN_USERNAME"].presence || "admin"
    expected_pass = ENV["ADMIN_PASSWORD"].presence

    # Fail closed in production: never serve the admin area with a missing or
    # default password. Locally we fall back to the default for convenience.
    if expected_pass.blank? || expected_pass == INSECURE_DEFAULT_PASSWORD
      if Rails.env.production?
        Rails.logger.error("[Admin] ADMIN_PASSWORD is unset or default — refusing admin access.")
        return head :service_unavailable
      end
      expected_pass ||= INSECURE_DEFAULT_PASSWORD
    end

    authenticate_or_request_with_http_basic("AcquireTMT Admin") do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username, expected_user) &
        ActiveSupport::SecurityUtils.secure_compare(password, expected_pass)
    end
  end
end

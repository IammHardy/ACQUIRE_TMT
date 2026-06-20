class Admin::BaseController < ApplicationController
  layout "admin"
  before_action :authenticate_admin

  INSECURE_DEFAULT_PASSWORD = "change-me-in-production".freeze

  # Verifies submitted credentials against ADMIN_USERNAME / ADMIN_PASSWORD.
  # Fails closed in production if the password is unset or still the default.
  def self.valid_credentials?(username, password)
    expected_user = ENV["ADMIN_USERNAME"].presence || "admin"
    expected_pass = ENV["ADMIN_PASSWORD"].presence

    if expected_pass.blank? || expected_pass == INSECURE_DEFAULT_PASSWORD
      return false if Rails.env.production?

      expected_pass ||= INSECURE_DEFAULT_PASSWORD
    end

    ActiveSupport::SecurityUtils.secure_compare(username.to_s, expected_user) &
      ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_pass)
  end

  private

  # Session-based gate. Unauthenticated requests are sent to the branded login.
  def authenticate_admin
    return if session[:admin_authenticated]

    session[:admin_return_to] = request.fullpath if request.get?
    redirect_to admin_login_path
  end
end

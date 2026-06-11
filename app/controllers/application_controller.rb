class ApplicationController < ActionController::Base
  include Authentication

  # The marketing site and tools are public by default. Controllers that need a
  # logged-in user (the dashboards) re-add `before_action :require_authentication`.
  allow_unauthenticated_access

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  # After sign in / sign up, land on the dashboard unless we were sent somewhere.
  def after_authentication_url
    session.delete(:return_to_after_authenticating) || dashboard_url
  end
end


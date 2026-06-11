class DashboardsController < ApplicationController
  before_action :require_authentication

  # Single entry point that renders the buyer or seller dashboard by role.
  def show
    @user = Current.user
    @tool_runs = @user.tool_runs.where(status: "complete").order(created_at: :desc) if @user.seller?
    render @user.buyer? ? :buyer : :seller
  end
end

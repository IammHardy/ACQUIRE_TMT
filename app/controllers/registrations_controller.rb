class RegistrationsController < ApplicationController
  # Public by default (ApplicationController); no auth needed to register.

  def new
    @user = User.new(role: User::ROLES.include?(params[:role]) ? params[:role] : "seller")
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      start_new_session_for @user
      claim_session_tool_runs
      redirect_to after_authentication_url, notice: "Welcome to AcquireTMT."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Attach any tool runs the visitor generated just before signing up.
  def claim_session_tool_runs
    ids = Array(session[:tool_run_ids])
    ToolRun.where(id: ids, user_id: nil).update_all(user_id: @user.id) if ids.any?
  end

  def registration_params
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation, :role)
  end
end

class SettingsController < ApplicationController
  layout "dashboard"
  before_action :require_authentication
  before_action :set_user

  def show
  end

  def update
    if @user.update(profile_params)
      redirect_to settings_path, notice: "Profile updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    unless @user.authenticate(params.dig(:user, :current_password).to_s)
      return redirect_to settings_path, alert: "Your current password is incorrect."
    end

    if @user.update(password_params)
      redirect_to settings_path, notice: "Password changed."
    else
      redirect_to settings_path, alert: @user.errors.full_messages.to_sentence
    end
  end

  private

  def set_user
    @user = Current.user
  end

  def profile_params
    params.require(:user).permit(:name, :email_address)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end

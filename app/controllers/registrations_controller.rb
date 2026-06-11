class RegistrationsController < ApplicationController
  # Public by default (ApplicationController); no auth needed to register.

  def new
    @user = User.new(role: User::ROLES.include?(params[:role]) ? params[:role] : "seller")
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      start_new_session_for @user
      redirect_to after_authentication_url, notice: "Welcome to AcquireTMT."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation, :role)
  end
end

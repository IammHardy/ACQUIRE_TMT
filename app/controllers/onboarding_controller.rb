class OnboardingController < ApplicationController
  before_action :require_authentication
  before_action :require_buyer

  def show
    @user = Current.user
  end

  def update
    @user = Current.user
    if @user.update(onboarding_params.merge(approval_status: "pending"))
      redirect_to dashboard_path
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def require_buyer
    redirect_to dashboard_path unless Current.user&.buyer?
  end

  def onboarding_params
    permitted = params.require(:user).permit(
      :buyer_type, :phone, :occupation, :bio, :experience_level, :personal_liquidity,
      :ev_min, :ev_max, :ebitda_min, :ebitda_max, :additional_context,
      mandate_industries: [], funding_sources: [], geographic_focus: []
    )
    # EV / EBITDA are entered in $M; store dollars to match deal figures.
    %i[ev_min ev_max ebitda_min ebitda_max].each do |key|
      permitted[key] = permitted[key].present? ? (permitted[key].to_f * 1_000_000).round : nil
    end
    permitted
  end
end

class DealsController < ApplicationController
  layout "dashboard"
  before_action :require_authentication
  before_action :set_deal, only: %i[show request_access]

  # Deals the buyer is engaged with (requested / approved / declined).
  def mine
    @accesses = Current.user.deal_accesses.includes(:deal).order(created_at: :desc)
  end

  def show
    @access = Current.user.deal_accesses.find_by(deal: @deal)
  end

  # A buyer requests the data room; admins approve before it unlocks.
  def request_access
    Current.user.deal_accesses.find_or_create_by(deal: @deal) { |a| a.status = "requested" }
    redirect_to deal_path(@deal), notice: "Access requested — our team will review and unlock the data room."
  end

  private

  def set_deal
    @deal = Deal.find(params[:id])
  end
end

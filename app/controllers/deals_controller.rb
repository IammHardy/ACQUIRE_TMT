class DealsController < ApplicationController
  layout "dashboard"
  before_action :require_authentication
  before_action :require_approved_buyer
  before_action :set_deal, only: %i[show request_access sign_nda]

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

  # After approval, the buyer signs the NDA to open the data room.
  def sign_nda
    access = Current.user.deal_accesses.find_by(deal: @deal)
    if access&.approved?
      access.update(nda_signed_at: Time.current)
      redirect_to deal_path(@deal), notice: "NDA signed — the data room is now open."
    else
      redirect_to deal_path(@deal), alert: "You need approved access before signing the NDA."
    end
  end

  private

  # Deals (and the data room) are only for approved buyers — not sellers, and
  # not buyers still pending review.
  def require_approved_buyer
    return if Current.user&.buyer? && Current.user.approved?

    redirect_to dashboard_path, alert: "Your buyer account must be approved before you can view deals."
  end

  def set_deal
    @deal = Deal.find(params[:id])
  end
end

class Admin::OffersController < Admin::BaseController
  before_action :set_deal

  def create
    if @deal.offers.create(offer_params).persisted?
      redirect_to edit_admin_deal_path(@deal), notice: "Offer added."
    else
      redirect_to edit_admin_deal_path(@deal), alert: "Couldn't add offer (buyer name required)."
    end
  end

  def destroy
    @deal.offers.find(params[:id]).destroy
    redirect_to edit_admin_deal_path(@deal), notice: "Offer removed."
  end

  private

  def set_deal
    @deal = Deal.find(params[:deal_id])
  end

  def offer_params
    params.require(:offer).permit(:buyer_name, :buyer_kind, :purchase_price,
      :upfront_cash_pct, :seller_note_pct, :equity_rollover_pct, :status)
  end
end

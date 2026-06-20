class Admin::DealsController < Admin::BaseController
  before_action :set_deal, only: %i[edit update destroy]

  def index
    @deals = Deal.order(created_at: :desc)
  end

  def new
    @deal = Deal.new(status: "active")
  end

  def create
    @deal = Deal.new(deal_params)
    if @deal.save
      notify_matching_buyers(@deal) if @deal.status == "active"
      redirect_to admin_deals_path, notice: "Deal created#{" — #{@matched} buyer alert(s) queued" if @matched.to_i.positive?}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @deal.update(deal_params)
      redirect_to admin_deals_path, notice: "Deal updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @deal.destroy
    redirect_to admin_deals_path, notice: "Deal removed."
  end

  private

  def set_deal
    @deal = Deal.find(params[:id])
  end

  # Email buyers whose mandate matches the new deal (background-delivered).
  def notify_matching_buyers(deal)
    buyers = User.matching_deal(deal)
    @matched = buyers.count
    buyers.find_each do |buyer|
      DealMailer.with(user: buyer, deal: deal).new_match.deliver_later
    end
  end

  def deal_params
    permitted = params.require(:deal).permit(
      :reference, :title, :industry, :revenue, :ebitda, :asking_price,
      :location, :teaser, :recurring, :status, :highlights_text, :user_id
    )
    # `highlights` is an array column; the form edits it as newline-separated text.
    permitted[:highlights] = permitted.delete(:highlights_text).to_s.split("\n").map(&:strip).reject(&:blank?)
    permitted
  end
end

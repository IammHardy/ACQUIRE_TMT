# Streams data-room documents through an authorization check on every download,
# so a confidential file is never reachable by a bare Active Storage URL — only
# an approved buyer who has unlocked (approved access + signed NDA) the deal can
# fetch it.
class DealDocumentsController < ApplicationController
  before_action :require_authentication

  def show
    deal = Deal.find(params[:deal_id])
    access = Current.user.deal_accesses.find_by(deal: deal)

    unless Current.user.buyer? && Current.user.approved? && access&.unlocked?
      return redirect_to deal_path(deal), alert: "Unlock the data room to download documents."
    end

    document = deal.deal_documents.find(params[:id])
    unless document.file.attached?
      return redirect_to deal_path(deal), alert: "That document is no longer available."
    end

    send_data document.file.download,
              filename: document.file.filename.to_s,
              type: document.file.content_type,
              disposition: "attachment"
  end
end

class ToolRun < ApplicationRecord
  belongs_to :lead, optional: true
  belongs_to :user, optional: true

  TOOL_TYPES = %w[valuation market_comps buyer_map].freeze

  validates :tool_type, inclusion: { in: TOOL_TYPES }

  enum :status, {
    pending: "pending",
    processing: "processing",
    complete: "complete",
    failed: "failed"
  }, default: "pending"
end

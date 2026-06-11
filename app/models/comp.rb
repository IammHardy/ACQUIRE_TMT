# A comparable business sale / valuation benchmark used by CompsEngine.
#
# Rows are seeded from free, public 2025 market data (broker & marketplace
# benchmarks — Empire Flippers, FE International, Aventis Advisors, Focus
# Bankers, etc.; see db/seeds.rb). Every row carries its source so the comps
# report can cite where the multiples came from. The multiples are real,
# sourced figures; the individual businesses are representative at SMB scale
# (kind: "benchmark") unless they are named public transactions (kind:
# "transaction").
class Comp < ApplicationRecord
  KINDS = %w[benchmark transaction].freeze

  validates :industry, :name, presence: true
  validates :kind, inclusion: { in: KINDS }

  scope :for_industry, ->(slug) { where(industry: slug) }

  # Comps in the same sector, closest in size to the given revenue first.
  def self.matching(industry, revenue)
    scope = for_industry(industry)
    scope = all if scope.none?
    scope.to_a.sort_by { |c| (c.revenue.to_i - revenue.to_i).abs }
  end

  def self.median(values)
    vals = values.compact.map(&:to_f).sort
    return 0 if vals.empty?

    mid = vals.size / 2
    vals.size.odd? ? vals[mid] : ((vals[mid - 1] + vals[mid]) / 2.0)
  end
end

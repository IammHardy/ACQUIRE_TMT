# A real, active business acquirer used by BuyerMatcher.
#
# Rows are seeded from public 2025 M&A reporting (PE roll-up platforms,
# strategic software acquirers, search-fund / SBA buyer classes, content
# aggregators — see db/seeds.rb). Each carries its source. `sectors` lists the
# industry slugs the buyer is active in; `min_revenue`/`max_revenue` bound the
# size they pursue (nil = open-ended).
class Buyer < ApplicationRecord
  TYPES = %w[pe_platform strategic search_fund sba aggregator].freeze

  TYPE_LABELS = {
    "pe_platform" => "PE-backed platforms",
    "strategic"   => "Strategic acquirers",
    "search_fund" => "Search funds & individuals",
    "sba"         => "SBA-backed buyers",
    "aggregator"  => "Portfolio aggregators"
  }.freeze

  validates :name, :buyer_type, presence: true
  validates :buyer_type, inclusion: { in: TYPES }

  scope :active, -> { where(active: true) }

  # Active buyers in the sector whose size range fits the business, larger /
  # more-acquisitive platforms first.
  def self.matching(industry, revenue)
    rev = revenue.to_i
    active
      .where("? = ANY (sectors)", industry)
      .select { |b| (b.min_revenue.nil? || rev >= b.min_revenue) && (b.max_revenue.nil? || rev <= b.max_revenue) }
      .sort_by { |b| -b.acquisitions_count }
  end

  def type_label
    TYPE_LABELS[buyer_type] || buyer_type
  end

  def website_url
    return nil if website.blank?

    website.start_with?("http") ? website : "https://#{website}"
  end

  def domain
    return nil if website.blank?

    URI.parse(website_url).host&.sub(/\Awww\./, "")
  rescue URI::InvalidURIError
    nil
  end

  # Logo via Google's favicon service (keyless, reliable). Nil if no website.
  def logo_url
    d = domain
    "https://www.google.com/s2/favicons?sz=128&domain=#{d}" if d.present?
  end
end

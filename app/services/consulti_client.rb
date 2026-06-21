require "net/http"
require "json"

# Thin wrapper around Consulti.ai's REST API (https://www.consulti.ai/api-docs).
# Powers live buyer sourcing (BuyerSourcer) when CONSULTI_API_KEY is set.
# Consulti is a verified-email B2B leads database; /leads/search returns people
# with their company + role, which we group into potential-acquirer companies.
class ConsultiClient
  BASE_URL = "https://www.consulti.ai/api/v1".freeze

  class NotConfigured < StandardError; end

  def self.configured?
    ENV["CONSULTI_API_KEY"].present?
  end

  # POST /leads/search — `filters` accepts industries[], titles[], countries[],
  # empMin/empMax, q, company, page. Charges 1 lead credit per result returned
  # (0 on no match). Returns an array of lead Hashes (string keys).
  def self.search_leads(filters, size: 25)
    raise NotConfigured, "CONSULTI_API_KEY is not set" unless configured?

    body = filters.compact.merge(size: size)
    Array(post("/leads/search", body)["leads"])
  end

  def self.post(path, body)
    uri = URI("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 25

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{ENV['CONSULTI_API_KEY']}"
    request.body = body.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise "Consulti API error #{response.code}: #{response.body.to_s.first(200)}"
    end

    JSON.parse(response.body)
  end
end

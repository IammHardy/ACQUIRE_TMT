require "net/http"
require "resolv"
require "ipaddr"

# Fetches a company's homepage and uses Claude to infer its TMT industry,
# business model, and qualitative value-driver signals. Returns a structured
# Hash; falls back to a neutral result if the page can't be fetched.
class WebsiteAnalyzer
  INDUSTRY_SLUGS = ValuationEngine::MULTIPLES.keys.freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are an M&A analyst specializing in technology, media and telecom (TMT)
    businesses. Given the text of a company's website, classify the business and
    extract signals a buyer would care about. Be decisive but honest about
    uncertainty. Only use the information provided; do not invent specifics.
  PROMPT

  SCHEMA = {
    "type" => "object",
    "properties" => {
      "industry" => {
        "type" => "string",
        "enum" => INDUSTRY_SLUGS,
        "description" => "Closest TMT sector. Use 'other' if none fit."
      },
      "industry_name" => { "type" => "string", "description" => "Human-readable sector name." },
      "business_model" => {
        "type" => "string",
        "description" => "One sentence: how the business makes money (e.g. recurring SaaS subscriptions, managed services retainers, ad-supported media)."
      },
      "summary" => { "type" => "string", "description" => "One-sentence description of what the company does." },
      "signals" => {
        "type" => "array",
        "items" => { "type" => "string" },
        "description" => "3-5 short value-driver signals (recurring revenue, niche, customer type, scale indicators)."
      },
      "products_services" => {
        "type" => "array",
        "items" => { "type" => "string" },
        "description" => "3-5 short tags for the company's main products/services (e.g. 'SMS API', 'managed cloud', 'SEO content'). 1-3 words each."
      },
      "end_markets" => {
        "type" => "array",
        "items" => { "type" => "string" },
        "description" => "2-4 short tags for the end markets / customer types served (e.g. 'B2B', 'enterprise', 'SMB', 'healthcare'). 1-2 words each."
      },
      "confidence" => {
        "type" => "string",
        "enum" => %w[low medium high],
        "description" => "Confidence in the classification given the available text."
      }
    },
    "required" => %w[industry industry_name business_model summary signals products_services end_markets confidence],
    "additionalProperties" => false
  }.freeze

  def initialize(website)
    @website = website.to_s.strip
  end

  # Analysis depends only on the website, so we cache the successful result by
  # host — repeat submits and the other tools reuse it instead of re-fetching
  # the page and re-calling the paid Claude API. Fallback (failed-fetch /
  # unavailable) results are deliberately NOT cached so a transient blip doesn't
  # stick a bad classification.
  CACHE_VERSION = "v1".freeze
  CACHE_TTL = 12.hours

  def call
    cached = Rails.cache.read(cache_key)
    return cached if cached

    text = fetch_text
    company = extract_company_name

    if text.blank?
      return fallback(company, "We couldn't read enough from the site to analyze it automatically.")
    end

    result = ClaudeClient.extract(
      system: SYSTEM_PROMPT,
      prompt: "Company website: #{normalized_url}\n\nWebsite text:\n#{text}",
      schema: SCHEMA,
      tool_name: "record_analysis"
    )
    result["company_name"] = company
    Rails.cache.write(cache_key, result, expires_in: CACHE_TTL)
    result
  rescue ClaudeClient::NotConfigured
    raise
  rescue => e
    Rails.logger.warn("[WebsiteAnalyzer] #{e.class}: #{e.message}")
    fallback(extract_company_name, "Automated analysis was unavailable for this site.")
  end

  private

  def cache_key
    host = begin
      URI.parse(normalized_url).host.to_s.sub(/\Awww\./, "").downcase
    rescue URI::InvalidURIError
      normalized_url
    end
    "website_analysis:#{CACHE_VERSION}:#{host}"
  end

  MAX_REDIRECTS = 3
  MAX_BYTES = 800_000

  # Fetches the page with SSRF protection: only http(s), and the host must
  # resolve to a public IP at every redirect hop (blocks localhost, private
  # ranges, and cloud metadata at 169.254.x). Follows redirects manually so a
  # public URL can't bounce us to an internal address.
  def fetch_text
    url = normalized_url
    MAX_REDIRECTS.times do
      uri = URI.parse(url)
      return "" unless safe_uri?(uri)

      response = http_get(uri)
      case response
      when Net::HTTPRedirection
        location = response["location"]
        return "" if location.blank?
        url = URI.join(url, location).to_s
        next
      when Net::HTTPSuccess
        return html_to_text(response.body.to_s.first(MAX_BYTES)).first(8000)
      else
        return ""
      end
    end
    ""
  rescue => e
    Rails.logger.warn("[WebsiteAnalyzer] fetch failed: #{e.class}: #{e.message}")
    ""
  end

  def http_get(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 8
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "AcquireTMT-Bot/1.0"
    http.request(request)
  end

  def safe_uri?(uri)
    return false unless %w[http https].include?(uri.scheme)
    return false if uri.host.blank?

    addresses = Resolv.getaddresses(uri.host)
    return false if addresses.empty?

    addresses.none? { |addr| blocked_ip?(addr) }
  rescue StandardError
    false
  end

  # Reject loopback, private, link-local (incl. 169.254.169.254 metadata),
  # CGNAT and unspecified addresses.
  def blocked_ip?(addr)
    ip = IPAddr.new(addr.to_s)
    return true if ip.loopback? || ip.private? || ip.link_local?

    if ip.ipv4?
      return true if IPAddr.new("100.64.0.0/10").include?(ip) || IPAddr.new("0.0.0.0/8").include?(ip)
    end
    false
  rescue IPAddr::Error
    true
  end

  def html_to_text(html)
    html
      .gsub(%r{<script.*?</script>}m, " ")
      .gsub(%r{<style.*?</style>}m, " ")
      .gsub(/<[^>]+>/, " ")
      .gsub(/&[a-z]+;/, " ")
      .gsub(/\s+/, " ")
      .strip
  end

  def normalized_url
    @normalized_url ||= @website.start_with?("http") ? @website : "https://#{@website}"
  end

  def extract_company_name
    host = URI.parse(normalized_url).host.to_s
    host.sub(/\Awww\./, "").split(".").first.to_s.capitalize.presence || "Your Business"
  rescue URI::InvalidURIError
    "Your Business"
  end

  def fallback(company, note)
    {
      "industry" => "other",
      "industry_name" => "Technology-enabled business",
      "business_model" => "Not determined from the website.",
      "summary" => note,
      "signals" => [],
      "products_services" => [],
      "end_markets" => [],
      "confidence" => "low",
      "company_name" => company
    }
  end
end

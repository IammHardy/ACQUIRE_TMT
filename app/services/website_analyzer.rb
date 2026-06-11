require "open-uri"

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
      "confidence" => {
        "type" => "string",
        "enum" => %w[low medium high],
        "description" => "Confidence in the classification given the available text."
      }
    },
    "required" => %w[industry industry_name business_model summary signals confidence],
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

  def fetch_text
    html = URI.parse(normalized_url).open(
      "User-Agent" => "AcquireTMT-Bot/1.0",
      open_timeout: 5,
      read_timeout: 8,
      redirect: true
    ).read
    html_to_text(html).first(8000)
  rescue => e
    Rails.logger.warn("[WebsiteAnalyzer] fetch failed: #{e.class}: #{e.message}")
    ""
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
      "confidence" => "low",
      "company_name" => company
    }
  end
end

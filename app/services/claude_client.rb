# Thin wrapper around the Anthropic Ruby SDK.
#
# `extract` forces Claude to return a structured object that matches `schema`
# by declaring a single tool and pinning tool_choice to it — the model must
# call the tool, so the tool's validated input IS our structured result.
class ClaudeClient
  MODEL = "claude-opus-4-8"

  class NotConfigured < StandardError; end

  def self.configured?
    ENV["ANTHROPIC_API_KEY"].present?
  end

  def self.client
    raise NotConfigured, "ANTHROPIC_API_KEY is not set" unless configured?

    @client ||= Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])
  end

  # Returns a plain string-keyed Hash matching `schema`.
  def self.extract(system:, prompt:, schema:, tool_name: "record", max_tokens: 1500)
    message = client.messages.create(
      model: MODEL,
      max_tokens: max_tokens,
      system: system,
      tools: [
        {
          name: tool_name,
          description: "Record the structured result for the application.",
          input_schema: schema
        }
      ],
      tool_choice: { type: "tool", name: tool_name },
      messages: [{ role: "user", content: prompt }]
    )

    block = message.content.find { |b| b.type.to_s == "tool_use" }
    raise "Claude returned no structured output" unless block

    raw = block[:input]
    hash = raw.is_a?(Hash) ? raw : raw.to_h
    JSON.parse(hash.to_json) # normalize to plain string-keyed Hash
  end
end

require "net/http"
require "json"

# Shared Anthropic Messages API client with retry logic.
# Include in any class that needs to call Claude.
#
#   class MyService
#     include AnthropicApi
#     def do_thing
#       result = call_anthropic_api(messages: [...], tools: [...])
#     end
#   end
module AnthropicApi
  extend ActiveSupport::Concern

  class ApiError < StandardError; end

  API_URI = URI("https://api.anthropic.com/v1/messages")
  DEFAULT_MODEL = "claude-haiku-4-5-20251001"
  RETRY_BACKOFFS = [ 5, 10, 20, 30, 30 ].freeze
  RETRYABLE_CODES = [ 429, 500, 502, 503, 529 ].freeze

  # Calls the Anthropic Messages API with tool use.
  #
  # Options:
  #   messages:    Array of message hashes (required)
  #   tools:       Array of tool definition hashes (required)
  #   system:      String system prompt (optional)
  #   model:       Model ID (default: claude-haiku-4-5-20251001)
  #   max_tokens:  Integer (default: 4096)
  #   tool_choice: Hash (default: { type: "any" })
  #
  # Returns the tool input hash from the first tool_use content block.
  # Raises AnthropicApi::ApiError on failure.
  def call_anthropic_api(messages:, tools:, system: nil, model: DEFAULT_MODEL,
                         max_tokens: 4096, tool_choice: { type: "any" })
    api_key = ENV.fetch("ANTHROPIC_API_KEY") { raise ApiError, "ANTHROPIC_API_KEY not configured" }

    body = {
      model: model,
      max_tokens: max_tokens,
      tools: tools,
      tool_choice: tool_choice,
      messages: messages
    }
    body[:system] = system if system.present?

    http              = Net::HTTP.new(API_URI.host, API_URI.port)
    http.use_ssl      = true
    http.open_timeout = 10
    http.read_timeout = 60

    request = Net::HTTP::Post.new(API_URI.path)
    request["Content-Type"]      = "application/json"
    request["x-api-key"]         = api_key
    request["anthropic-version"] = "2023-06-01"
    request.body = body.to_json

    response = nil
    retries  = 0
    loop do
      begin
        response = http.request(request)
        code = response.code.to_i
        break if code == 200

        if RETRYABLE_CODES.include?(code) && retries < RETRY_BACKOFFS.size
          wait = RETRY_BACKOFFS[retries]
          Rails.logger.warn "AnthropicApi #{code} — retry #{retries + 1}/#{RETRY_BACKOFFS.size} after #{wait}s"
          sleep wait
          retries += 1
          next
        end

        raise ApiError, error_message_for(code)
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise ApiError, "Request timed out. Please try again." if retries >= RETRY_BACKOFFS.size

        wait = RETRY_BACKOFFS[retries]
        Rails.logger.warn "AnthropicApi timeout — retry #{retries + 1}/#{RETRY_BACKOFFS.size} after #{wait}s"
        sleep wait
        retries += 1
        next
      end
    end

    parsed     = JSON.parse(response.body)
    tool_block = parsed["content"]&.find { |b| b["type"] == "tool_use" }
    raise ApiError, "No tool response returned by LLM" unless tool_block

    tool_block["input"]
  end

  private

  def error_message_for(code)
    case code
    when 429      then "Too many requests right now. Please try again in a moment."
    when 503, 529 then "The AI is overloaded right now. Please try again in a moment."
    when 500, 502 then "The AI service is temporarily unavailable. Please try again."
    else "AI request failed (error #{code}). Please try again."
    end
  end
end

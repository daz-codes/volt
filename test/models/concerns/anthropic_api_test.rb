require "test_helper"

class AnthropicApiTest < ActiveSupport::TestCase
  # Minimal includer class to test the module
  class FakeClient
    include AnthropicApi

    # Expose error_message_for for testing
    public :error_message_for
  end

  setup do
    @client = FakeClient.new
  end

  test "error_message_for returns rate limit message for 429" do
    assert_match(/Too many requests/, @client.error_message_for(429))
  end

  test "error_message_for returns overloaded message for 529" do
    assert_match(/overloaded/, @client.error_message_for(529))
  end

  test "error_message_for returns server error message for 500" do
    assert_match(/temporarily unavailable/, @client.error_message_for(500))
  end

  test "error_message_for returns generic message for unknown codes" do
    msg = @client.error_message_for(418)
    assert_match(/error 418/, msg)
  end

  test "call_anthropic_api raises when ANTHROPIC_API_KEY is missing" do
    original = ENV["ANTHROPIC_API_KEY"]
    ENV.delete("ANTHROPIC_API_KEY")

    assert_raises(AnthropicApi::ApiError) do
      @client.call_anthropic_api(
        messages: [ { role: "user", content: "test" } ],
        tools: [ { name: "create_workout" } ]
      )
    end
  ensure
    ENV["ANTHROPIC_API_KEY"] = original if original
  end
end

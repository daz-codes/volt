require "test_helper"

class LLMContext::ActivitiesTest < ActiveSupport::TestCase
  test "resolves a display slug through to the module via aliases" do
    skip "Iron Engine module not yet defined" unless defined?(LLMContext::Activities::IronEngine)
    assert_equal LLMContext::Activities::IronEngine, LLMContext::Activities.for("iron-engine")
  end

  test "resolves the canonical slug directly" do
    skip "Iron Engine module not yet defined" unless defined?(LLMContext::Activities::IronEngine)
    assert_equal LLMContext::Activities::IronEngine, LLMContext::Activities.for("kettlebell")
  end

  test "canonical_slug collapses aliases to canonical form" do
    assert_equal "kettlebell", LLMContext::Activities.canonical_slug("iron-engine")
    assert_equal "kettlebell", LLMContext::Activities.canonical_slug("kettlebell")
  end

  test "canonical_slug is one-hop (does not loop)" do
    # Intentional: ALIASES is kept flat so a future buggy edit can't hang callers.
    # Feed a slug that maps to another slug and assert we get the first hop only.
    assert_equal "alternator", LLMContext::Activities.canonical_slug("barry-s")
  end

  test "returns nil for an unknown slug" do
    assert_nil LLMContext::Activities.for("does-not-exist")
  end

  test "for! raises on unknown slug" do
    assert_raises(LLMContext::Activities::UnknownActivity) do
      LLMContext::Activities.for!("does-not-exist")
    end
  end
end

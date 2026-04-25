require "test_helper"

class LLMContext::ActivitiesTest < ActiveSupport::TestCase
  test "resolves a display slug through to the module via aliases" do
    assert_equal LLMContext::Activities::IronEngine, LLMContext::Activities.for("iron-engine")
  end

  test "resolves the canonical slug directly" do
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

  test "tread-shred slug routes to Alternator" do
    assert_equal "alternator", LLMContext::Activities.canonical_slug("tread-shred")
    assert_equal LLMContext::Activities::Alternator, LLMContext::Activities.for("tread-shred")
  end

  test "barry-s slug routes to Alternator" do
    assert_equal LLMContext::Activities::Alternator, LLMContext::Activities.for("barry-s")
  end

  test "hybrid-race slug routes to HybridRace" do
    assert_equal LLMContext::Activities::HybridRace, LLMContext::Activities.for("hybrid-race")
  end

  test "strong-stations slug aliases to DekaAtlas" do
    assert_equal "deka-atlas", LLMContext::Activities.canonical_slug("strong-stations")
    assert_equal LLMContext::Activities::DekaAtlas, LLMContext::Activities.for("strong-stations")
  end

  test "renamed display slugs route to existing modules" do
    assert_equal LLMContext::Activities::IronEngine,   LLMContext::Activities.for("kettlebell-hell")
    assert_equal LLMContext::Activities::Transformer,  LLMContext::Activities.for("volt-strong")
    assert_equal LLMContext::Activities::Dynamo,       LLMContext::Activities.for("mega-fit")
    assert_equal LLMContext::Activities::Alternator,   LLMContext::Activities.for("pump-grind")
    assert_equal LLMContext::Activities::Ohm,          LLMContext::Activities.for("volt-flow")
    assert_equal LLMContext::Activities::Turbine,      LLMContext::Activities.for("engine-room")
  end

  test "circuit-breaker slug now routes to FunctionalMuscle (absorbed)" do
    assert_equal "functional-muscle", LLMContext::Activities.canonical_slug("circuit-breaker")
    assert_equal LLMContext::Activities::FunctionalMuscle, LLMContext::Activities.for("circuit-breaker")
    assert_equal LLMContext::Activities::FunctionalMuscle, LLMContext::Activities.for("f45")
  end
end

require "test_helper"

class WorkoutLLMGenerator::ContractPromptBuilderTest < ActiveSupport::TestCase
  def build(activity_slug: "kettlebell", duration_mins: 45, athlete: "test athlete", session_notes: nil, banned_override: [])
    WorkoutLLMGenerator::ContractPromptBuilder.new(
      activity: LLMContext::Activities.for!(activity_slug),
      duration_mins: duration_mins,
      athlete_block: athlete,
      session_notes: session_notes,
      banned_equipment_override: banned_override
    ).build
  end

  test "contains all required XML tags in order" do
    prompt = build
    expected_order = %w[<role> <athlete> <task> <contract> <global_rules> <session_shape> <examples>]
    positions = expected_order.map { |tag| prompt.index(tag) }
    assert positions.none?(&:nil?), "missing tags: #{expected_order.zip(positions).reject { |_, p| p }.map(&:first)}"
    assert_equal positions, positions.sort, "tags must appear in order"
  end

  test "omits session_notes tag when no notes given" do
    refute_includes build, "<session_notes>"
  end

  test "includes session_notes tag when notes given" do
    assert_includes build(session_notes: "no running please"), "<session_notes>"
  end

  test "iron-engine prompt includes KETTLEBELL ONLY purity statement" do
    assert_includes build, "KETTLEBELL ONLY"
  end

  test "iron-engine prompt does not mention cardio machines as allowed or in examples" do
    prompt = build
    allowed_line = prompt[/ALLOWED EQUIPMENT:([^\n]+)/, 1]
    refute_nil allowed_line
    refute_match(/treadmill|assault.?bike|rower|ski.?erg/i, allowed_line)

    examples_block = prompt[/<examples>(.*?)<\/examples>/m, 1]
    refute_nil examples_block
    refute_match(/"equipment"\s*:\s*"(treadmill|assault_bike|rowing_machine|ski_erg)"/, examples_block)
    refute_match(/"name"\s*:\s*"[^"]*(treadmill|assault bike|rower|ski erg)/i, examples_block)
  end

  test "examples tag contains three serialised workouts" do
    prompt = build
    examples_block = prompt[/\<examples\>(.*?)\<\/examples\>/m, 1]
    refute_nil examples_block
    assert_equal 3, examples_block.scan(/"goal"\s*:/).length
  end

  test "global_rules block contains the rest-work rule" do
    assert_match(/rest.*never.*exceed/i, build[/\<global_rules\>(.*?)\<\/global_rules\>/m, 1])
  end

  test "banned_equipment_override merges into contract banned list" do
    prompt = build(banned_override: %w[pull_up_bar])
    banned = prompt[/BANNED EQUIPMENT:([^\n]+)/, 1]
    refute_nil banned
    assert_includes banned, "pull_up_bar"
  end

  test "contract_override replaces the activity contract" do
    activity = LLMContext::Activities.for!("kettlebell")
    override = activity::CONTRACT.merge(finisher: :required, core: :never)
    prompt = WorkoutLLMGenerator::ContractPromptBuilder.new(
      activity: activity, duration_mins: 45, athlete_block: "x",
      contract_override: override
    ).build
    assert_match(/FINISHER: required/, prompt)
    assert_match(/CORE SECTION: never/, prompt)
  end
end

class WorkoutLLMGenerator::RoutingTest < ActiveSupport::TestCase
  setup do
    @original = ENV["WORKOUT_PROMPT_LEGACY_ACTIVITIES"]
    ENV.delete("WORKOUT_PROMPT_LEGACY_ACTIVITIES")
  end

  teardown do
    ENV["WORKOUT_PROMPT_LEGACY_ACTIVITIES"] = @original
  end

  # @activity_slug at runtime is the canonical slug ("kettlebell" for Iron Engine),
  # because WorkoutLLMGenerator#initialize normalises display slugs through
  # ACTIVITY_ALIASES before storing. Set it to "kettlebell" in these tests.

  test "contract_path? returns true by default for a registered activity" do
    gen = WorkoutLLMGenerator.allocate
    gen.instance_variable_set(:@activity_slug, "kettlebell")
    assert gen.send(:contract_path?)
  end

  test "contract_path? returns false when canonical slug is in legacy flag" do
    ENV["WORKOUT_PROMPT_LEGACY_ACTIVITIES"] = "kettlebell,turbine"
    gen = WorkoutLLMGenerator.allocate
    gen.instance_variable_set(:@activity_slug, "kettlebell")
    refute gen.send(:contract_path?)
  end

  test "contract_path? returns false when legacy flag uses a display slug that aliases to the canonical" do
    ENV["WORKOUT_PROMPT_LEGACY_ACTIVITIES"] = "iron-engine"
    gen = WorkoutLLMGenerator.allocate
    gen.instance_variable_set(:@activity_slug, "kettlebell")
    refute gen.send(:contract_path?)
  end

  test "contract_path? returns false when slug is not in the activity registry" do
    gen = WorkoutLLMGenerator.allocate
    gen.instance_variable_set(:@activity_slug, "nonexistent-activity")
    refute gen.send(:contract_path?)
  end
end

require "test_helper"

class WorkoutLLMGenerator::ContractPromptBuilderTest < ActiveSupport::TestCase
  def build(activity_slug: "kettlebell", duration_mins: 45, athlete: "test athlete", session_notes: nil, banned_override: [], intensity_style: nil)
    WorkoutLLMGenerator::ContractPromptBuilder.new(
      activity: LLMContext::Activities.for!(activity_slug),
      duration_mins: duration_mins,
      athlete_block: athlete,
      session_notes: session_notes,
      banned_equipment_override: banned_override,
      intensity_style: intensity_style
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
    refute_includes build, "</session_notes>"
  end

  test "includes session_notes tag when notes given" do
    assert_includes build(session_notes: "no running please"), "<session_notes>"
  end

  test "omits intensity_style tag when not given" do
    refute_includes build, "</intensity_style>"
  end

  test "includes intensity_style tag when set" do
    prompt = build(intensity_style: "zone_2")
    assert_includes prompt, "<intensity_style>\nzone_2\n</intensity_style>"
  end

  test "intensity_style tag appears before session_notes tag" do
    prompt = build(intensity_style: "max_effort", session_notes: "no running")
    intensity_pos = prompt.index("<intensity_style>")
    notes_pos = prompt.index("<session_notes>")
    assert intensity_pos && notes_pos, "both tags must be present"
    assert intensity_pos < notes_pos, "intensity_style must come before session_notes"
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

  test "global_rules block tells the LLM to name the intensity style in the goal sentence" do
    rules = build[/\<global_rules\>(.*?)\<\/global_rules\>/m, 1]
    refute_nil rules
    assert_match(/goal.*intensity_style/im, rules)
    assert_match(/zone 2/, rules)
    assert_match(/max effort/, rules)
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

  test "banned_exercise_patterns appear in the contract block as readable terms" do
    contract_block = build[/\<contract\>(.*?)\<\/contract\>/m, 1]
    refute_nil contract_block
    assert_match(/BANNED EXERCISE NAMES/, contract_block)
    assert_match(/assault bike/i, contract_block)
  end

  test "omits ALLOWED EQUIPMENT line when activity allows none (e.g. ohm)" do
    contract_block = build(activity_slug: "ohm")[/\<contract\>(.*?)\<\/contract\>/m, 1]
    refute_nil contract_block
    refute_match(/ALLOWED EQUIPMENT:/, contract_block)
  end

  test "omits BANNED EQUIPMENT line when activity bans none (e.g. alternator)" do
    contract_block = build(activity_slug: "alternator")[/\<contract\>(.*?)\<\/contract\>/m, 1]
    refute_nil contract_block
    refute_match(/BANNED EQUIPMENT:/, contract_block)
  end

  test "flow activities (ohm) emit a continuous-sequence shape without bookends" do
    shape = build(activity_slug: "ohm")[/\<session_shape\>(.*?)\<\/session_shape\>/m, 1]
    refute_nil shape
    refute_match(/Warm-up \(\d+ min\)/, shape)
    refute_match(/Cool-down \(\d+ min\)/, shape)
    assert_match(/continuous flowing sequence/i, shape)
  end
end


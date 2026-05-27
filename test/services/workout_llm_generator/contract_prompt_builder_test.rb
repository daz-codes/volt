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
    prompt = build(activity_slug: "general-fitness", intensity_style: "low")
    assert_includes prompt, "<intensity_style>\nlow\n</intensity_style>"
  end

  test "intensity_style tag appears before session_notes tag" do
    prompt = build(intensity_style: "high", session_notes: "no running")
    intensity_pos = prompt.index("<intensity_style>")
    notes_pos = prompt.index("<session_notes>")
    assert intensity_pos && notes_pos, "both tags must be present"
    assert intensity_pos < notes_pos, "intensity_style must come before session_notes"
  end

  test "intensity_style block embeds the activity's intensity_guide line when defined" do
    prompt = build(activity_slug: "ohm", intensity_style: "high")
    assert_match(/<intensity_style>\nhigh\n\nFor Volt Flow, treat `high` as: [^\n]*power vinyasa/i, prompt)
  end

  test "intensity_style block omits the guide line when the contract does not define one" do
    # general-fitness has no intensity_guide → tag contains just the value, falls back to global rules
    prompt = build(activity_slug: "general-fitness", intensity_style: "low")
    assert_includes prompt, "<intensity_style>\nlow\n</intensity_style>"
  end

  test "iron-engine prompt includes KETTLEBELL ONLY purity statement" do
    assert_includes build, "KETTLEBELL ONLY"
  end

  test "iron-engine prompt does not mention cardio machines as allowed or in examples" do
    prompt = build
    allowed_line = prompt[/ALLOWED EQUIPMENT[^:]*:([^\n]+)/, 1]
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

  test "examples surface explicit intensity_style annotations" do
    examples_block = build(activity_slug: "kettlebell")[/\<examples\>(.*?)\<\/examples\>/m, 1]
    refute_nil examples_block
    assert_match(/"intensity_style"\s*:\s*"high"/, examples_block)
    assert_match(/"intensity_style"\s*:\s*"medium"/, examples_block)
  end

  test "global_rules block contains the rest-work rule" do
    assert_match(/rest.*never.*exceed/i, build[/\<global_rules\>(.*?)\<\/global_rules\>/m, 1])
  end

  test "global_rules block tells the LLM to name the intensity style in the goal sentence" do
    rules = build[/\<global_rules\>(.*?)\<\/global_rules\>/m, 1]
    refute_nil rules
    assert_match(/goal.*intensity_style/im, rules)
    assert_match(/low/, rules)
    assert_match(/high/, rules)
  end

  test "banned_equipment_override merges into contract banned list" do
    prompt = build(banned_override: %w[pull_up_bar])
    banned = prompt[/BANNED EQUIPMENT[^:]*:([^\n]+)/, 1]
    refute_nil banned
    assert_includes banned, "pull_up_bar"
  end

  test "allowed equipment line excludes anything that's also in the banned list" do
    # Kettlebell activity allows kettlebells; ban pull_up_bar via override.
    # The ALLOWED line must NOT contradict the BAN.
    prompt = build(banned_override: %w[pull_up_bar])
    allowed = prompt[/ALLOWED EQUIPMENT[^:]*:([^\n]+)/, 1]
    banned  = prompt[/BANNED EQUIPMENT[^:]*:([^\n]+)/, 1]
    refute_nil allowed
    refute_nil banned
    refute_match(/pull_up_bar/, allowed, "ALLOWED must not list anything in BANNED")
    assert_match(/pull_up_bar/, banned)
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

  test "RUNNING SUBSTITUTION line appears for running-allowed activity when treadmill is banned" do
    # Deka Mile allows treadmill; if the user bans it, the prompt must tell the LLM
    # to substitute Compromised Run with the user's preferred cardio machine.
    prompt = build(activity_slug: "deka-mile", banned_override: %w[treadmill assault_bike ski_erg])
    sub_line = prompt[/RUNNING SUBSTITUTION:[^\n]+/]
    refute_nil sub_line, "expected RUNNING SUBSTITUTION line in prompt"
    assert_match(/Row/, sub_line)
    refute_match(/SkiErg/, sub_line)
    refute_match(/Air Bike/, sub_line)
  end

  test "RUNNING SUBSTITUTION line is omitted when treadmill is not banned" do
    contract_block = build(activity_slug: "deka-mile")[/\<contract\>(.*?)\<\/contract\>/m, 1]
    refute_nil contract_block
    refute_match(/RUNNING SUBSTITUTION:/, contract_block)
  end

  test "RUNNING SUBSTITUTION line is omitted when activity disallows treadmill anyway" do
    # Deka Strong bans treadmill at the contract level — running isn't a real choice for the LLM
    # to make, so the substitution hint would be noise.
    contract_block = build(activity_slug: "deka-strong", banned_override: %w[treadmill])[/\<contract\>(.*?)\<\/contract\>/m, 1]
    refute_nil contract_block
    refute_match(/RUNNING SUBSTITUTION:/, contract_block)
  end

  test "RUNNING SUBSTITUTION line is omitted when no cardio replacement is available to the user" do
    contract_block = build(activity_slug: "deka-mile",
      banned_override: %w[treadmill rowing_machine ski_erg assault_bike])[/\<contract\>(.*?)\<\/contract\>/m, 1]
    refute_nil contract_block
    refute_match(/RUNNING SUBSTITUTION:/, contract_block)
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

  test "omits hybrid_style tag for non-race activities" do
    refute_includes build(activity_slug: "kettlebell"), "<hybrid_style>"
  end

  test "injects hybrid_style tag for race-family activities" do
    prompt = build(activity_slug: "hyrox")
    assert_includes prompt, "<hybrid_style>"
    assert_includes prompt, "</hybrid_style>"
  end

  test "hybrid_style tag appears immediately after global_rules" do
    prompt = build(activity_slug: "hyrox")
    global_pos = prompt.index("</global_rules>")
    hybrid_pos = prompt.index("<hybrid_style>")
    assert global_pos && hybrid_pos, "both tags must be present"
    assert global_pos < hybrid_pos, "hybrid_style must come after global_rules"
  end

  test "task tag uses the activity module name when user_activity_name is absent" do
    prompt = build(activity_slug: "hyrox")
    assert_match(%r{<task>\nGenerate a \d+-minute Hyrox session\.\n</task>}, prompt)
  end

  test "filters examples strictly to matching intensity_style — drops unflagged" do
    # Hyrox high-tagged examples: Race Day Test, Iron & Fire, Sprint Bookends.
    # With strict filtering, a high request shows ONLY high-tagged examples —
    # the unflagged "flexible" examples are excluded to avoid biasing the LLM
    # back toward medium-flavoured patterns. Sample size caps at
    # EXAMPLE_SAMPLE_SIZE so the visible count may be lower than the pool.
    high_prompt = build(activity_slug: "hyrox", intensity_style: "high")
    high_block = high_prompt[/\<examples\>(.*?)\<\/examples\>/m, 1]
    refute_nil high_block
    high_count = high_block.scan(/"goal"\s*:/).length
    sample_size = WorkoutLLMGenerator::ContractPromptBuilder::EXAMPLE_SAMPLE_SIZE
    assert high_count <= sample_size, "high pool sample must not exceed EXAMPLE_SAMPLE_SIZE (got #{high_count})"
    refute_match(/"Zone Two Engine"/, high_block)
    refute_match(/"Continuous Engine"/, high_block)
    refute_match(/"Mixed Hybrid"/, high_block)
    refute_match(/"Two Engines"/, high_block)
  end

  test "randomly samples EXAMPLE_SAMPLE_SIZE examples when the pool exceeds it" do
    # Hyrox has 13 examples — without sampling the LLM would see all of them
    # and pattern-match the top-of-list each generation. Sampling rotates the
    # slice each call so variety emerges naturally across sessions.
    prompt = build(activity_slug: "hyrox")
    block = prompt[/\<examples\>(.*?)\<\/examples\>/m, 1]
    refute_nil block
    assert_equal WorkoutLLMGenerator::ContractPromptBuilder::EXAMPLE_SAMPLE_SIZE,
                 block.scan(/"goal"\s*:/).length
  end

  test "returns the whole pool when it is at or below EXAMPLE_SAMPLE_SIZE" do
    # kettlebell has 3 examples; with a sample size of 3 there is nothing to
    # drop, so every generation gets the full set.
    prompt = build(activity_slug: "kettlebell")
    block = prompt[/\<examples\>(.*?)\<\/examples\>/m, 1]
    refute_nil block
    assert_equal 3, block.scan(/"goal"\s*:/).length
  end

  test "sampling rotates which examples appear across generations" do
    # Burn 6 generations and collect the names of the examples shown. With
    # 13 Hyrox examples and a sample size of 3, the same trio coming up six
    # times in a row is vanishingly unlikely — so two distinct trios across
    # the six calls is a low-flake assertion that sampling is actually random.
    seen_trios = 6.times.map do
      block = build(activity_slug: "hyrox")[/\<examples\>(.*?)\<\/examples\>/m, 1]
      block.scan(/"name"\s*:\s*"([^"]+)"/).flatten.first(3).sort
    end
    assert seen_trios.uniq.length >= 2, "sampling should produce at least two different trios across 6 calls; got #{seen_trios.uniq.length}"
  end

  test "task tag uses user_activity_name when provided (free-form typed activity)" do
    prompt = WorkoutLLMGenerator::ContractPromptBuilder.new(
      activity:           LLMContext::Activities.for!("general-fitness"),
      duration_mins:      45,
      athlete_block:      "test athlete",
      user_activity_name: "Dumbbell workout"
    ).build
    assert_match(%r{<task>\nGenerate a 45-minute Dumbbell workout session\.\n</task>}, prompt)
  end
end


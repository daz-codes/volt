require "test_helper"

class LLMContext::ContractIntegrityTest < ActiveSupport::TestCase
  REQUIRED_CONTRACT_KEYS = %i[
    purity allowed_equipment banned_equipment allowed_formats primary_formats
    warm_up cool_down finisher core
  ].freeze

  WARM_UP_KEYS = %i[easy_cardio kb_activation bodyweight_activation flow].freeze
  COOL_DOWN_KEYS = %i[full_body_stretch lower_focus upper_focus savasana].freeze
  FINISHER_VALUES = %i[optional required forbidden].freeze
  CORE_VALUES = %i[optional required never].freeze

  VALID_EQUIPMENT_TERMS = (User::EQUIPMENT_SLUGS + %w[bodyweight]).freeze

  def assert_activity_valid(mod)
    contract = mod::CONTRACT
    REQUIRED_CONTRACT_KEYS.each do |k|
      assert contract.key?(k), "#{mod}::CONTRACT missing key #{k}"
    end

    assert_includes WARM_UP_KEYS, contract[:warm_up], "#{mod}: warm_up key not in shared vocabulary"
    assert_includes COOL_DOWN_KEYS, contract[:cool_down], "#{mod}: cool_down key not in shared vocabulary"
    assert_includes FINISHER_VALUES, contract[:finisher], "#{mod}: finisher must be optional/required/forbidden"
    assert_includes CORE_VALUES, contract[:core], "#{mod}: core must be optional/required/never"

    (Array(contract[:allowed_equipment]) + Array(contract[:banned_equipment])).each do |term|
      assert_includes VALID_EQUIPMENT_TERMS, term,
        "#{mod}: equipment term #{term.inspect} is not a User::EQUIPMENT_SLUG or 'bodyweight'"
    end

    examples = mod::EXAMPLES
    assert_equal 3, examples.length, "#{mod}: need exactly 3 EXAMPLES"
    examples.each_with_index do |ex, i|
      assert ex[:name].present?, "#{mod}: example #{i} missing :name"
      assert ex[:goal].present?, "#{mod}: example #{i} missing :goal"
      assert ex[:duration_mins].is_a?(Integer), "#{mod}: example #{i} missing :duration_mins"
      sections = Array(ex[:sections])
      assert sections.length >= 3, "#{mod}: example #{i} needs warm-up + main + cool-down"
      assert_match(/warm/i, sections.first[:name].to_s, "#{mod}: example #{i} first section must be warm-up")
      assert_match(/cool/i, sections.last[:name].to_s,  "#{mod}: example #{i} last section must be cool-down")
    end

    banned   = Array(contract[:banned_equipment])
    allowed  = Array(contract[:allowed_equipment]) + %w[bodyweight]
    patterns = Array(contract[:banned_exercise_patterns])

    examples.each_with_index do |ex, i|
      ex[:sections].each do |section|
        next if section[:name].to_s.match?(/warm|cool/i)
        Array(section[:exercises]).each do |exercise|
          equipment = exercise[:equipment]
          if equipment
            assert_not_includes banned,  equipment.to_s,
              "#{mod}: example #{i} section #{section[:name].inspect} uses banned equipment #{equipment}"
            assert_includes     allowed, equipment.to_s,
              "#{mod}: example #{i} section #{section[:name].inspect} uses equipment #{equipment.inspect} that is not in allowed_equipment"
          end
          patterns.each do |pattern|
            refute_match pattern, exercise[:name].to_s,
              "#{mod}: example #{i} exercise name #{exercise[:name].inspect} matches banned pattern #{pattern.inspect}"
          end
        end
      end
    end
  end

  test "Iron Engine contract is valid" do
    assert_activity_valid(LLMContext::Activities::IronEngine)
  end

  test "Turbine contract is valid" do
    assert_activity_valid(LLMContext::Activities::Turbine)
  end

  test "Ohm contract is valid" do
    assert_activity_valid(LLMContext::Activities::Ohm)
  end

  test "Dynamo contract is valid" do
    assert_activity_valid(LLMContext::Activities::Dynamo)
  end

  test "Hyrox contract is valid" do
    assert_activity_valid(LLMContext::Activities::Hyrox)
  end

  test "Deka Fit contract is valid" do
    assert_activity_valid(LLMContext::Activities::DekaFit)
  end

  test "Deka contract is valid" do
    assert_activity_valid(LLMContext::Activities::Deka)
  end

  test "Deka Strong contract is valid" do
    assert_activity_valid(LLMContext::Activities::DekaStrong)
  end

  test "Deka Mile contract is valid" do
    assert_activity_valid(LLMContext::Activities::DekaMile)
  end

  test "Deka Atlas contract is valid" do
    assert_activity_valid(LLMContext::Activities::DekaAtlas)
  end

  test "Volt Octathlon contract is valid" do
    assert_activity_valid(LLMContext::Activities::VoltOctathlon)
  end

  test "Alternator contract is valid" do
    assert_activity_valid(LLMContext::Activities::Alternator)
  end

  test "Transformer contract is valid" do
    assert_activity_valid(LLMContext::Activities::Transformer)
  end

  test "Circuit Breaker contract is valid" do
    assert_activity_valid(LLMContext::Activities::CircuitBreaker)
  end

  test "CrossFit contract is valid" do
    assert_activity_valid(LLMContext::Activities::CrossFit)
  end

  test "Functional Muscle contract is valid" do
    assert_activity_valid(LLMContext::Activities::FunctionalMuscle)
  end

  test "General Fitness contract is valid" do
    assert_activity_valid(LLMContext::Activities::GeneralFitness)
  end
end

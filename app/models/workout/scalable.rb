module Workout::Scalable
  extend ActiveSupport::Concern

  SCALE_FACTORS = {
    2 => { reps: 0.8, distance: 0.75, calories: 0.8, rounds: -1, ladder: -2, mountain_peak: -1, emom_mins: -2 },
    4 => { reps: 1.2, distance: 1.25, calories: 1.2, rounds: 1,  ladder: 2,  mountain_peak: 1,  emom_mins: 2 }
  }.freeze

  # Formats that should never be deterministically scaled
  UNSCALED_FORMATS = %w[tabata hundred matrix switchback].freeze

  # Section categories that should never be scaled
  UNSCALED_CATEGORIES = %w[warm_up cool_down].freeze

  WEIGHT_CUE_DOWN = {
    "heavy" => "moderate", "moderate" => "light-moderate",
    "light-moderate" => "light", "working weight" => "light-moderate"
  }.freeze

  WEIGHT_CUE_UP = {
    "light" => "light-moderate", "light-moderate" => "moderate",
    "moderate" => "heavy", "working weight" => "moderate-heavy"
  }.freeze

  SCALING_SYSTEM_PROMPT = <<~PROMPT
    You are an expert personal trainer. You will receive a workout structure and a target difficulty level.
    Your job is to scale the workout to match that level using the create_workout tool.

    Rules:
    - Keep the same overall session shape: same number of sections, same section names, same formats.
    - Leave warm-up and cool-down sections EXACTLY as they are — do not modify them.
    - For beginner scaling: substitute complex exercises for simpler alternatives (e.g. burpees → step-ups,
      box jumps → step-ups, devil press → DB deadlifts), reduce reps significantly (~40-50% of original),
      reduce rounds, use lighter weight cues, add more rest. The workout should feel accessible and safe.
    - For elite scaling: substitute exercises for harder variations (e.g. box jumps → box jump burpees,
      KB swings → KB snatch, push-ups → clap push-ups), increase reps (~30-40% above original),
      add rounds, use heavier weight cues, reduce rest. The workout should feel brutal.
    - Maintain the same equipment requirements — don't introduce equipment that wasn't in the original.
    - Keep the same duration target.
  PROMPT

  def scale_to(level)
    source = (original_structure || structure).deep_dup
    return source if level == 3

    if level.in?([ 2, 4 ])
      scale_deterministic(source, level)
    else
      scale_with_llm(source, level)
    end
  end

  private

  def scale_deterministic(structure, level)
    factors = SCALE_FACTORS[level]

    structure["sections"].each do |section|
      next if UNSCALED_CATEGORIES.include?(section["category"])
      next if UNSCALED_FORMATS.include?(section["format"])

      scale_section(section, factors)
    end

    structure
  end

  def scale_section(section, factors)
    case section["format"]
    when "rounds", "for_time"
      scale_rounds_section(section, factors)
    when "ladder"
      scale_ladder_section(section, factors)
    when "mountain"
      scale_mountain_section(section, factors)
    when "emom"
      scale_emom_section(section, factors)
    when "amrap", "straight"
      scale_exercises(section["exercises"], factors)
    end
  end

  def scale_rounds_section(section, factors)
    has_rounds = section["rounds"].to_i > 1
    is_for_time = section["format"] == "for_time"

    if has_rounds
      section["rounds"] = [ section["rounds"].to_i + factors[:rounds], 2 ].max
    end

    # For for_time: scale reps only when there aren't multiple rounds
    # For rounds: always scale exercises
    scale_exercises(section["exercises"], factors) unless is_for_time && has_rounds
  end

  def scale_ladder_section(section, factors)
    if section["start"].to_i > section["end"].to_i
      # Descending ladder (e.g. 10-1): adjust start
      section["start"] = [ section["start"].to_i + factors[:ladder], 3 ].max
    else
      # Ascending ladder: adjust end
      section["end"] = [ section["end"].to_i + factors[:ladder], 3 ].max
    end
  end

  def scale_mountain_section(section, factors)
    section["peak"] = [ section["peak"].to_i + factors[:mountain_peak], 2 ].max if section["peak"]
  end

  def scale_emom_section(section, factors)
    if section["duration_mins"].to_i > 0
      section["duration_mins"] = [ section["duration_mins"].to_i + factors[:emom_mins], 4 ].max
    end
    scale_exercises(section["exercises"], factors) unless section["emom_style"] == "rotating"
  end

  def scale_exercises(exercises, factors)
    return unless exercises

    exercises.each do |exercise|
      scale_reps(exercise, factors[:reps]) if exercise["reps"].to_i > 0
      scale_distance(exercise, factors[:distance]) if exercise["distance_m"].to_i > 0
      scale_calories(exercise, factors[:calories]) if exercise["calories"].to_i > 0
      scale_weight_cues(exercise, factors[:reps] < 1 ? :down : :up) if exercise["notes"].present?
    end
  end

  def scale_reps(exercise, factor)
    raw = exercise["reps"] * factor
    exercise["reps"] = if raw >= 10
      (raw / 5.0).round * 5
    else
      [ raw.round, 1 ].max
    end
  end

  def scale_distance(exercise, factor)
    raw = exercise["distance_m"] * factor
    is_running = exercise["name"].to_s.match?(/run|sprint|jog|treadmill/i)
    step = is_running ? 100 : 25
    exercise["distance_m"] = [ (raw / step.to_f).round * step, step ].max
  end

  def scale_calories(exercise, factor)
    raw = exercise["calories"] * factor
    exercise["calories"] = [ (raw / 5.0).round * 5, 5 ].max
  end

  def scale_weight_cues(exercise, direction)
    cues = direction == :down ? WEIGHT_CUE_DOWN : WEIGHT_CUE_UP
    notes = exercise["notes"]
    cues.each do |from, to|
      notes = notes.gsub(/\b#{Regexp.escape(from)}\b/i, to)
    end
    exercise["notes"] = notes
  end

  def scale_with_llm(structure, level)
    api_client = Class.new { include AnthropicApi }.new

    direction = level == 1 ? "beginner" : "elite"
    fallback_level = level == 1 ? 2 : 4

    prompt = build_scaling_prompt(structure, direction)

    result = api_client.call_anthropic_api(
      system: SCALING_SYSTEM_PROMPT,
      messages: [ { role: "user", content: prompt } ],
      tools: [ WorkoutLLMGenerator::TOOL_DEFINITION ]
    )

    scaled = result.dig("structure") || structure
    # Preserve original warm-up and cool-down
    preserve_bookend_sections(structure, scaled)
    scaled
  rescue StandardError => _e
    scale_deterministic(structure, fallback_level)
  end

  def build_scaling_prompt(structure, direction)
    <<~PROMPT
      Scale this workout to #{direction} level. Return the full modified structure using the create_workout tool.

      Original workout structure:
      #{JSON.pretty_generate(structure)}

      Remember: keep section names, formats, and structure the same. Only modify exercises, reps, rounds, and weight cues.
      Warm-up and cool-down must remain exactly as they are.
    PROMPT
  end

  def preserve_bookend_sections(original, scaled)
    original_sections = original["sections"] || []
    scaled_sections = scaled["sections"] || []

    original_sections.each_with_index do |section, i|
      if UNSCALED_CATEGORIES.include?(section["category"]) && scaled_sections[i]
        scaled_sections[i] = section.deep_dup
      end
    end
  end
end

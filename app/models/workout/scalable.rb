module Workout::Scalable
  extend ActiveSupport::Concern

  SCALE_FACTORS = {
    2 => { reps: 0.8, distance: 0.75, calories: 0.8, rounds: -1, ladder: -2, mountain_peak: -1, emom_mins: -2 },
    4 => { reps: 1.2, distance: 1.25, calories: 1.2, rounds: 1,  ladder: 2,  mountain_peak: 1,  emom_mins: 2 }
  }.freeze

  # Formats that should never be deterministically scaled
  UNSCALED_FORMATS = %w[tabata hundred matrix].freeze

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

  # Placeholder for Task 4 — LLM scaling
  def scale_with_llm(structure, level)
    # Fall back to deterministic for now
    fallback_level = level == 1 ? 2 : 4
    scale_deterministic(structure, fallback_level)
  end
end

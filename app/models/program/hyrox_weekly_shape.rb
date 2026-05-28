module Program::HyroxWeeklyShape
  extend ActiveSupport::Concern

  # The activity name the LLM should use for each session type. Matched
  # against `Activity.name` (case-insensitive, find_or_create_by).
  HYROX        = "Hyrox".freeze
  ENGINE_ROOM  = "Engine Room".freeze
  TRANSFORMER  = "Transformer".freeze

  # Canonical session shapes that get composed into a week. Each shape names
  # the activity, the intensity_style, and a short note to seed the LLM.
  SHAPES = {
    hyrox_low:     { activity: HYROX,       intensity_style: "low",
                     notes: "easy aerobic Hyrox session — bookends or long continuous circuit at conversational pace" },
    hyrox_medium:  { activity: HYROX,       intensity_style: "medium",
                     notes: "race-prep working pace — mix run intervals with station blocks at RPE 7-8" },
    hyrox_high:    { activity: HYROX,       intensity_style: "high",
                     notes: "race-day energy — strength block first, all-out cardio with long recovery" },
    cardio_low:    { activity: ENGINE_ROOM, intensity_style: "low",
                     notes: "long zone-2 cardio engine builder — single block or stacked single-modality blocks" },
    strength_high: { activity: TRANSFORMER, intensity_style: "high",
                     notes: "heavy compound strength — 3-5 reps near-max, full recovery between sets" },
    strength_med:  { activity: TRANSFORMER, intensity_style: "medium",
                     notes: "hypertrophy / accessory strength — 6-10 reps, 90-120s rest" }
  }.freeze

  # Per-session-count plans. The user's rules:
  #   1 → medium Hyrox
  #   2 → low cardio + medium Hyrox
  #   3 → low Hyrox + high Hyrox + low cardio
  #   4 → low Hyrox + high strength + low cardio + medium Hyrox
  #   5 → low cardio + low Hyrox × 2 + high strength + high Hyrox
  #   6 → 5 + another low cardio
  #   7 → 6 + another medium strength
  #   8+ → 7 + extra low Hyrox sessions for each additional
  BASE_PLANS = {
    1 => %i[hyrox_medium],
    2 => %i[cardio_low hyrox_medium],
    3 => %i[hyrox_low hyrox_high cardio_low],
    4 => %i[hyrox_low strength_high cardio_low hyrox_medium],
    5 => %i[cardio_low hyrox_low hyrox_low strength_high hyrox_high],
    6 => %i[cardio_low hyrox_low hyrox_low strength_high hyrox_high cardio_low],
    7 => %i[cardio_low hyrox_low hyrox_low strength_high hyrox_high cardio_low strength_med]
  }.freeze

  module ClassMethods
    # Returns an ordered Array of session prescriptions (one per session in
    # the week). Each entry is a Hash: { activity:, intensity_style:, notes: }.
    # For session counts above 7, the extras are filled with hyrox_low.
    def hyrox_weekly_shape(sessions_per_week)
      n = sessions_per_week.to_i
      return [] if n <= 0

      keys = BASE_PLANS[n] || (BASE_PLANS[7] + Array.new(n - 7, :hyrox_low))
      keys.map { |key| SHAPES.fetch(key) }
    end
  end
end

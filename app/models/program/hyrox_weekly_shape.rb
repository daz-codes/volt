module Program::HyroxWeeklyShape
  extend ActiveSupport::Concern

  # The activity name the LLM should use for each session type. These match
  # the canonical user-facing names (Engine Room and Volt Strong are slug
  # aliases for the internal turbine and transformer contracts).
  HYROX        = "Hyrox".freeze
  ENGINE_ROOM  = "Engine Room".freeze
  VOLT_STRONG  = "Volt Strong".freeze

  # Canonical session shapes that get composed into a week. Each shape names
  # the activity, the intensity_style, a short label for prefilling the form's
  # session-focus input, and a longer note to seed the LLM.
  SHAPES = {
    hyrox_low:     { activity: HYROX,       intensity_style: "low",
                     label: "Low intensity Hyrox",
                     notes: "easy aerobic Hyrox session — bookends or long continuous circuit at conversational pace" },
    hyrox_medium:  { activity: HYROX,       intensity_style: "medium",
                     label: "Medium intensity Hyrox",
                     notes: "race-prep working pace — mix run intervals with station blocks at RPE 7-8" },
    hyrox_high:    { activity: HYROX,       intensity_style: "high",
                     label: "High intensity Hyrox",
                     notes: "race-day energy — strength block first, all-out cardio with long recovery" },
    cardio_low:    { activity: ENGINE_ROOM, intensity_style: "low",
                     label: "Low intensity cardio focused",
                     notes: "long zone-2 cardio engine builder — single block or stacked single-modality blocks" },
    strength_high: { activity: VOLT_STRONG, intensity_style: "high",
                     label: "High intensity strength focused",
                     notes: "heavy compound strength — 3-5 reps near-max, full recovery between sets" },
    strength_med:  { activity: VOLT_STRONG, intensity_style: "medium",
                     label: "Medium intensity strength focused",
                     notes: "hypertrophy / accessory strength — 6-10 reps, 90-120s rest" }
  }.freeze

  # Per-session-count plans. Composition follows the user's rules; order is
  # arranged so EVERY high-intensity session is followed by at least one
  # low-intensity session later in the week (recovery rule).
  #
  #   1 → medium Hyrox
  #   2 → low cardio + medium Hyrox
  #   3 → low Hyrox + high Hyrox + low cardio                      (high@2 → low@3)
  #   4 → low Hyrox + high strength + low cardio + medium Hyrox    (high@2 → low@3)
  #   5 → low Hyrox + high strength + low cardio + high Hyrox + low Hyrox
  #                                                                (high@2 → low@3; high@4 → low@5)
  #   6 → 5 + extra low cardio inserted at slot 5 to follow the second high
  #   7 → 6 + medium strength near the end (medium triggers no recovery rule)
  #   8+ → 7 + extra low Hyrox sessions appended (always satisfies the rule
  #         since the appended sessions are all low)
  BASE_PLANS = {
    1 => %i[hyrox_medium],
    2 => %i[cardio_low hyrox_medium],
    3 => %i[hyrox_low hyrox_high cardio_low],
    4 => %i[hyrox_low strength_high cardio_low hyrox_medium],
    5 => %i[hyrox_low strength_high cardio_low hyrox_high hyrox_low],
    6 => %i[hyrox_low strength_high cardio_low hyrox_high cardio_low hyrox_low],
    7 => %i[hyrox_low strength_high cardio_low hyrox_high cardio_low strength_med hyrox_low]
  }.freeze

  module ClassMethods
    # Returns an ordered Array of session prescriptions (one per session in
    # the week). Each entry is a Hash: { activity:, intensity_style:, label:, notes: }.
    # For session counts above 7, the extras are filled with hyrox_low.
    def hyrox_weekly_shape(sessions_per_week)
      n = sessions_per_week.to_i
      return [] if n <= 0

      keys = BASE_PLANS[n] || (BASE_PLANS[7] + Array.new(n - 7, :hyrox_low))
      keys.map { |key| SHAPES.fetch(key) }
    end

    # Just the short labels — for prefilling the new-program form's session
    # focus inputs. The user can overwrite any of them; the SessionFocus
    # parser turns the (possibly-edited) text back into activity + intensity
    # at submit time.
    def hyrox_weekly_labels(sessions_per_week)
      hyrox_weekly_shape(sessions_per_week).map { |slot| slot[:label] }
    end
  end
end

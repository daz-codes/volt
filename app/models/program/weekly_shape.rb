module Program::WeeklyShape
  extend ActiveSupport::Concern

  # Activity names the LLM should use for each session type. These match the
  # canonical user-facing names (Engine Room and Volt Strong are slug aliases
  # for the internal turbine and transformer contracts respectively).
  ENGINE_ROOM = "Engine Room".freeze
  VOLT_STRONG = "Volt Strong".freeze
  DEKA_ATLAS  = "Deka Atlas".freeze

  # Race-family activities for which we prescribe a weekly shape. Hyrox and
  # the three Deka variants that are NOT Atlas all use the same base plan
  # with their own activity name in the "primary" slot. Deka Atlas overlays
  # additional rules (see apply_atlas_rules below).
  PLAN_ACTIVITIES = [ "Hyrox", "Deka Fit", "Deka Strong", "Deka Mile", DEKA_ATLAS ].freeze

  # Canonical session shapes. Templates reference `:primary_*` for the
  # program's headline activity (Hyrox / Deka Fit / etc.) — filled in at
  # materialisation time. Engine Room and Volt Strong are fixed.
  SHAPES = {
    primary_low:    { intensity_style: "low",    label: "Low intensity %<activity>s" },
    primary_medium: { intensity_style: "medium", label: "Medium intensity %<activity>s" },
    primary_high:   { intensity_style: "high",   label: "High intensity %<activity>s" },
    cardio_low:     { activity: ENGINE_ROOM, intensity_style: "low",
                      label: "Low intensity cardio focused",
                      notes: "long zone-2 cardio engine builder — single block or stacked single-modality blocks" },
    strength_high:  { activity: VOLT_STRONG, intensity_style: "high",
                      label: "High intensity strength focused",
                      notes: "heavy compound strength — 3-5 reps near-max, full recovery between sets" },
    strength_med:   { activity: VOLT_STRONG, intensity_style: "medium",
                      label: "Medium intensity strength focused",
                      notes: "hypertrophy / accessory strength — 6-10 reps, 90-120s rest" }
  }.freeze

  # Per-session-count plans. Composition follows the user's rules; order is
  # arranged so EVERY high-intensity session is followed by at least one
  # low-intensity session later in the week (recovery rule).
  BASE_PLANS = {
    1 => %i[primary_medium],
    2 => %i[cardio_low primary_medium],
    3 => %i[primary_low primary_high cardio_low],
    4 => %i[primary_low strength_high cardio_low primary_medium],
    5 => %i[primary_low strength_high cardio_low primary_high primary_low],
    6 => %i[primary_low strength_high cardio_low primary_high cardio_low primary_low],
    7 => %i[primary_low strength_high cardio_low primary_high cardio_low strength_med primary_low]
  }.freeze

  # Deka Atlas-specific orderings for the session counts where the Atlas
  # overlay (cardio_low → strength_med) would break the recovery rule by
  # removing the low session after a high. For these counts we reorder
  # explicitly so every high still has a low after it. Counts not listed
  # here fall through to BASE_PLANS + apply_atlas_rules.
  ATLAS_BASE_PLANS = {
    3 => %i[strength_med primary_high primary_low],
    4 => %i[strength_med strength_high primary_low primary_medium]
  }.freeze

  # Notes seed for primary-activity slots — chosen by intensity. The
  # `%<activity>s` placeholder is filled with the program's primary activity.
  PRIMARY_NOTES = {
    "low"    => "easy aerobic %<activity>s session — bookends or long continuous circuit at conversational pace",
    "medium" => "race-prep working pace — mix run intervals with station blocks at RPE 7-8",
    "high"   => "race-day energy — strength block first, all-out cardio with long recovery"
  }.freeze

  module ClassMethods
    # Returns an ordered Array of session prescriptions for a race-family
    # activity. Each entry: { activity:, intensity_style:, label:, notes: }.
    # Session counts above 7 are extended with primary_low sessions.
    # Returns [] for activities outside the race-family allowlist.
    def weekly_shape(activity_name, sessions_per_week)
      name = activity_name.to_s
      n    = sessions_per_week.to_i
      return [] if n <= 0
      return [] unless PLAN_ACTIVITIES.include?(name)

      # Atlas overrides for the counts where the cardio→strength swap would
      # break the recovery rule; otherwise fall through to base + overlay.
      atlas_override = name == DEKA_ATLAS ? ATLAS_BASE_PLANS[n] : nil
      keys  = atlas_override || BASE_PLANS[n] || (BASE_PLANS[7] + Array.new(n - 7, :primary_low))
      shape = keys.map { |key| materialise_slot(key, name) }
      shape = apply_atlas_rules(shape) if name == DEKA_ATLAS && atlas_override.nil?
      shape
    end

    # Just the prefill labels — for serialising into the new-program form.
    def weekly_labels(activity_name, sessions_per_week)
      weekly_shape(activity_name, sessions_per_week).map { |slot| slot[:label] }
    end

    # ----- Backward-compatible Hyrox aliases (existing callers/tests) -----

    def hyrox_weekly_shape(sessions_per_week)
      weekly_shape("Hyrox", sessions_per_week)
    end

    def hyrox_weekly_labels(sessions_per_week)
      weekly_labels("Hyrox", sessions_per_week)
    end

    private

    def materialise_slot(key, activity_name)
      template = SHAPES.fetch(key)
      if key.to_s.start_with?("primary_")
        intensity = template[:intensity_style]
        {
          activity:        activity_name,
          intensity_style: intensity,
          label:           format(template[:label], activity: activity_name),
          notes:           format(PRIMARY_NOTES.fetch(intensity), activity: activity_name)
        }
      else
        template.merge(label: template[:label].dup)
      end
    end

    # Deka Atlas overlay applied AFTER the base shape is materialised:
    #   1) Replace EVERY cardio_low (Engine Room) slot with a medium-intensity
    #      strength session — Atlas athletes get accessory strength volume
    #      instead of a zone-2 cardio day.
    #   2) When 2+ high-intensity sessions exist in the week (any activity),
    #      downgrade ONE of them to medium. Prefer downgrading strength_high
    #      (Volt Strong) so the activity-specific high Atlas session remains
    #      the peak.
    def apply_atlas_rules(shape)
      shape = shape.map do |slot|
        slot[:activity] == ENGINE_ROOM ? materialise_slot(:strength_med, DEKA_ATLAS) : slot
      end

      high_indices = shape.each_with_index.select { |s, _| s[:intensity_style] == "high" }.map(&:last)
      return shape unless high_indices.size >= 2

      downgrade_idx = high_indices.find { |i| shape[i][:activity] == VOLT_STRONG } || high_indices.last
      shape[downgrade_idx] = materialise_slot(:strength_med, DEKA_ATLAS)
      shape
    end
  end
end

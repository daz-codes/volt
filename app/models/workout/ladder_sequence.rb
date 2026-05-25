module Workout::LadderSequence
  module_function

  UNIT_LABELS = { "reps" => "reps", "calories" => "cal", "distance_m" => "m", "kg" => "kg" }.freeze
  OVERRIDE_KEYS = %w[start end step peak].freeze

  # Returns the numeric rung sequence for this exercise in this section.
  # Falls through to the section defaults when the exercise has no overrides.
  def values_for(section, exercise)
    sv   = (exercise["start"] || section["start"]).to_f
    ev   = (exercise["end"]   || section["end"]).to_f
    step = ((exercise["step"] || section["step"]).to_f).nonzero?&.abs || 1.0

    case section["format"].to_s
    when "mountain"
      pk = (exercise["peak"] || section["peak"]).to_f
      ev = sv if ev.zero?
      up   = sv.step(pk,    step).to_a
      down = (pk - step).step(ev, -step).to_a
      coerce(up + down)
    else # ladder (and anything else falls through to ladder shape)
      seq = sv <= ev ? sv.step(ev, step).to_a : sv.step(ev, -step).to_a
      coerce(seq)
    end
  end

  # Returns the effective `varies` for this exercise — the override, then the
  # legacy `metric` field, then the section default. Used to choose the unit.
  def varies_for(section, exercise)
    exercise["varies"].presence || exercise["metric"].presence || section["varies"].to_s
  end

  # Short label for this exercise's effective metric: "reps", "cal", "m", "kg".
  def unit_label_for(section, exercise)
    UNIT_LABELS[varies_for(section, exercise)] || varies_for(section, exercise)
  end

  # True when at least one exercise carries a real scale override (varies/start/
  # end/step/peak), meaning the renderer must show per-exercise sequences.
  # The legacy `metric`-only field does NOT count — it just relabels the unit.
  def has_per_exercise_overrides?(section)
    Array(section["exercises"]).any? do |ex|
      ex["varies"].present? || OVERRIDE_KEYS.any? { |k| ex[k].present? }
    end
  end

  private_class_method def self.coerce(arr)
    arr.map { |v| v == v.to_i ? v.to_i : v.round(2) }
  end
end

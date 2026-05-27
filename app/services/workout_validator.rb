# WorkoutValidator performs deterministic, rule-based checks on a generated
# workout data hash (the raw LLM output before it's persisted) and auto-fixes
# any violations it can resolve without another API call.
#
# Usage:
#   validator    = WorkoutValidator.new(workout_data, duration_mins: 45)
#   workout_data = validator.validate_and_fix
#   validator.fixes.each    { |msg| Rails.logger.info("[WorkoutValidator] Fixed: #{msg}") }
#   validator.warnings.each { |msg| Rails.logger.warn("[WorkoutValidator] Warn:  #{msg}") }
#
# validate_and_fix mutates the hash in place AND returns it.
class WorkoutValidator
  # Max total work units (reps + calories combined) within a single EMOM circuit minute.
  # With max 2 exercises at 5 reps each, 10 is the realistic cap.
  EMOM_REP_CAP = 10

  # Cardio machines in circuit EMOMs: hard cap of 10 cal per exercise.
  # On a SkiErg, Air Bike, or Rowing Machine you can't hit more than ~10 cal/min
  # while sharing that minute with other exercises.
  EMOM_CARDIO_CAL_CAP = 10
  CARDIO_MACHINE_PATTERN = /ski|erg|row|bike|assault|air.?bike|concept|treadmill/i.freeze
  CARDIO_RUN_PATTERN     = /\b(run|jog|sprint)(ning|s)?\b/i.freeze

  # Valid step-size range per ladder/mountain metric.
  # distance_m has no upper bound — just a minimum of 10.
  LADDER_STEP_MIN = { "reps" => 1, "calories" => 5, "distance_m" => 10, "kg" => 5 }.freeze
  LADDER_STEP_MAX = { "reps" => 5, "calories" => 10, "kg" => 10 }.freeze  # distance_m: no max

  # Exercises that work one side at a time — rep counts must be even so both sides get equal work.
  ALTERNATING_PATTERN = /lunge|split.?squat|step.?up|single.?arm|single.?leg|one.?arm|one.?leg|pistol|alternating|unilateral/i.freeze

  attr_reader :fixes, :warnings

  # Ordered preference for swapping running exercises when user has no treadmill.
  # First slug the user actually has wins.
  RUN_REPLACEMENTS = [
    { slug: "rowing_machine", name: "Row" },
    { slug: "ski_erg",        name: "SkiErg" },
    { slug: "assault_bike",   name: "Air Bike" }
  ].freeze

  def initialize(workout_data, duration_mins:, main_tag_slug: nil, available_equipment: nil)
    @data                = workout_data
    @duration_mins       = duration_mins.to_i
    @main_tag_slug       = main_tag_slug.to_s
    @available_equipment = available_equipment.nil? ? nil : Array(available_equipment).map(&:to_s)
    @fixes               = []
    @warnings            = []
  end

  def validate_and_fix
    sections = Array(@data.dig("structure", "sections"))
    normalize_continuous_circuit_format(sections)
    ensure_section_categories(sections)

    sections.each_with_index do |section, idx|
      case section["format"]
      when "emom"
        fix_emom_structure(section, idx)
        fix_emom_alternating_inference(section, idx)
        fix_emom_reps(section, idx)
      when "continuous_circuit"
        fix_continuous_circuit_structure(section, idx)
      when "tabata"
        fix_tabata_duration(section, idx)
        fix_tabata_exercise_count(section, idx)
      when "ladder", "mountain"
        fix_ladder_rung_count_parity(section, idx)
        fix_ladder_step(section, idx)
        fix_mountain_end(section) if section["format"] == "mountain"
      when "hundred"
        fix_hundred(section, idx)
      end
    end

    fix_mountain_rep_sequence(sections)
    fix_exercise_name_programming(sections)
    fix_notes_as_programming(sections)
    fix_bear_complex_notes(sections)
    fix_strength_weight_cues(sections)
    fix_race_weight_on_non_stations(sections)
    fix_jump_rope_calories(sections)
    fix_for_time_rounds(sections)
    fix_alternating_reps(sections)
    fix_clean_rep_counts(sections)
    fix_clean_distances(sections)
    fix_swap_run_for_no_treadmill(sections) if user_has_no_treadmill?
    fix_treadmill_calories(sections)
    fix_rest_secs(sections)
    fix_rest_ratio(sections)
    fix_long_cardio_rounds_to_straight(sections)
    fix_single_set_sections(sections)
    fix_tabata_exercise_metrics(sections)
    fix_tabata_exercise_names(sections)
    fix_tabata_exercise_notes(sections)
    fix_ladder_exercise_notes(sections)
    fix_treadmill_ladder(sections)
    fix_ladder_rest(sections)
    fix_atlas_barbell_press(sections)
    fix_overhead_weight_cap(sections)
    fix_redundant_section_notes(sections)
    fix_duplicate_section_exercise_notes(sections)
    fix_continuous_circuit_exercise_metrics(sections)
    fix_emom_notes(sections)
    fix_cardio_interval_split(sections)
    fix_threshold_interval_duration(sections)
    fix_cardio_missing_metric(sections)
    fix_cardio_machine_reps(sections)
    fix_speed_language(sections)
    fix_switchback_inference(sections)
    fix_ladder_switchback_strip_metrics(sections)
    if @main_tag_slug == "turbine"
      fix_turbine_formats(sections)
      fix_turbine_block_durations(sections)
    end
    fix_hyrox_banned_machines(sections) if @main_tag_slug == "hyrox"
    fix_deka_mile_compromised_run_cap(sections) if @main_tag_slug == "deka-mile"
    fix_kettlebell_non_kb_exercises(sections) if @main_tag_slug == "kettlebell"
    dedup_warmup_sections(sections)
    dedup_cooldown_sections(sections)
    check_cooldown(sections)

    fix_warmup_format(sections)
    fix_amrap_minimum_exercises(sections)
    fix_timed_section_durations(sections)
    dedup_identical_sections(sections)
    dedup_structurally_identical_sections(sections)
    cap_main_section_count(sections) unless @main_tag_slug == "functional-muscle"

    if @main_tag_slug == "functional-muscle"
      fix_fm_remove_activation(sections)
      fix_fm_continuous_circuit_reps(sections)
      fix_fm_tabata_remove_non_compounds(sections)
      fix_fm_merge_strength_sections(sections)
      fix_fm_strength_sets(sections)
      fix_fm_strip_machine_suffix(sections)
      fix_fm_trim_metabolic_blocks(sections)
      fix_fm_ensure_abs(sections)
      fix_fm_section_order(sections)
    end

    fix_goal_durations(sections)

    @data
  end

  private

  # Assign a category to each section so downstream methods can rely on it.
  # First pass infers from name patterns; second pass detects finishers.
  def ensure_section_categories(sections)
    # First pass: infer from name patterns
    sections.each do |section|
      next if Workout::CATEGORIES.include?(section["category"])

      name = section["name"].to_s
      section["category"] = if name.match?(Workout::WARMUP_NAME_PATTERN)
        "warm_up"
      elsif name.match?(Workout::COOLDOWN_NAME_PATTERN)
        "cool_down"
      else
        "main"
      end
    end

    # Second pass: detect finisher (last non-cool-down section with tabata/hundred/for_time format)
    last_main_idx = sections.rindex { |s| s["category"] != "cool_down" }
    if last_main_idx
      candidate = sections[last_main_idx]
      if %w[tabata hundred for_time].include?(candidate["format"]) && candidate["category"] == "main"
        has_prior_main = sections[0...last_main_idx].any? { |s| s["category"] == "main" }
        candidate["category"] = "finisher" if has_prior_main
      end
    end
  end

  # Defensive: if the LLM emits `format: emom + emom_style: rotating` (the legacy
  # encoding), normalize it to the first-class `format: continuous_circuit` so
  # downstream rules don't have to know about both shapes.
  def normalize_continuous_circuit_format(sections)
    sections.each do |section|
      next unless section["format"] == "emom" && section["emom_style"] == "rotating"
      section["format"] = "continuous_circuit"
      section.delete("emom_style")
      @fixes << "'#{section["name"]}': normalized legacy emom+rotating to continuous_circuit"
    end
  end

  # EMOM circuit: total reps per minute must not exceed the rep cap.
  # Continuous circuits (one exercise per minute) are their own format and don't
  # hit this method. Also enforces a per-exercise calorie cap for cardio machines.
  def fix_emom_reps(section, idx)
    period      = section["period_mins"].to_i.nonzero? || 1
    alternating = section["alternating"]
    exercises   = Array(section["exercises"])
    changed     = []

    # When exercises rotate one-per-period, each one owns its full period —
    # don't aggregate-cap across the list. Cardio cal cap still applies
    # per-exercise (scaled by period).
    return if alternating && exercises.size >= 2 && fix_emom_cardio_cal_only(section, exercises, period, changed)

    cap = EMOM_REP_CAP * period

    # Zero pass: convert distance_m to calories on cardio machines in circuit EMOMs.
    # Distance targets (250m ski, 500m row) are impossible within a shared minute.
    exercises.each do |ex|
      next unless ex["distance_m"].to_i > 0
      if ex["name"].to_s.match?(CARDIO_MACHINE_PATTERN)
        old_dist = ex["distance_m"]
        ex.delete("distance_m")
        ex["calories"] = EMOM_CARDIO_CAL_CAP
        changed << "#{ex["name"]} #{old_dist}m → #{EMOM_CARDIO_CAL_CAP} cal (distance too long for circuit EMOM)"
      else
        # Non-machine distance in a circuit EMOM is also suspect — strip it
        old_dist = ex["distance_m"]
        ex.delete("distance_m")
        ex["reps"] ||= 10
        changed << "#{ex["name"]} #{old_dist}m → #{ex["reps"]} reps (distance invalid in circuit EMOM)"
      end
    end

    # First pass: clamp cardio machine calories independently (cap scales by period)
    cardio_cap = EMOM_CARDIO_CAL_CAP * period
    exercises.each do |ex|
      next unless ex["calories"].to_i > cardio_cap
      next unless ex["name"].to_s.match?(CARDIO_MACHINE_PATTERN)
      old = ex["calories"]
      ex["calories"] = cardio_cap
      changed << "#{ex["name"]} cal #{old} → #{cardio_cap}"
    end

    # Second pass: scale total if still over cap
    workload_exercises = exercises.select { |e| e["reps"].to_i > 0 || e["calories"].to_i > 0 }
    total = workload_exercises.sum { |e| e["reps"].to_i + e["calories"].to_i }

    if total > cap && workload_exercises.any?
      scale = cap.to_f / total
      workload_exercises.each do |ex|
        if ex["reps"].to_i > 0
          ex["reps"] = [ (ex["reps"].to_i * scale).floor, 1 ].max
        end
        if ex["calories"].to_i > 0
          ex["calories"] = [ (ex["calories"].to_i * scale).floor, 1 ].max
        end
      end
      new_total = workload_exercises.sum { |e| e["reps"].to_i + e["calories"].to_i }
      changed << "total #{total} → #{new_total} (cap: #{cap})"
    end

    @fixes << "EMOM '#{section["name"]}': #{changed.join("; ")}" if changed.any?
  end

  # Per-exercise cardio cap pass for rotating EMOMs (where each exercise owns
  # its full period). Returns true when called, so the surrounding aggregate
  # rep-scaling pass is skipped.
  def fix_emom_cardio_cal_only(section, exercises, period, changed)
    cardio_cap = EMOM_CARDIO_CAL_CAP * period
    exercises.each do |ex|
      next unless ex["calories"].to_i > cardio_cap
      next unless ex["name"].to_s.match?(CARDIO_MACHINE_PATTERN)
      old = ex["calories"]
      ex["calories"] = cardio_cap
      changed << "#{ex["name"]} cal #{old} → #{cardio_cap}"
    end
    @fixes << "EMOM '#{section["name"]}': #{changed.join("; ")}" if changed.any?
    true
  end

  # EMOM structure cap. Standard circuit EMOMs (period_mins:1, alternating
  # false-or-nil) share one minute, so two exercises is the practical max
  # (FM allows three legacy 3-ex emoms before they were promoted to
  # continuous_circuit). With period_mins > 1 or alternating: true the
  # cap does not apply — the LLM is intentionally describing E2MOMs, rotating
  # blocks, or strength stations.
  def fix_emom_structure(section, idx)
    exercises  = Array(section["exercises"])
    period     = section["period_mins"].to_i.nonzero? || 1
    alternates = section["alternating"]

    return if period > 1 || alternates

    is_fm = @main_tag_slug == "functional-muscle"
    max_exercises = is_fm ? 3 : 2
    if exercises.size > max_exercises
      section["exercises"] = exercises.first(max_exercises)
      section.delete("notes") # LLM notes reference the old exercise count
      @fixes << "EMOM circuit '#{section["name"]}': trimmed to #{max_exercises} exercises (was #{exercises.size})"
      exercises = section["exercises"]
    end

    exercises.each do |ex|
      reps = ex["reps"].to_i
      next if reps <= 0
      clean = reps <= 7 ? 5 : 10
      next if clean == reps
      ex["reps"] = clean
      @fixes << "EMOM circuit '#{section["name"]}': #{ex["name"]} reps #{reps} → #{clean} (must be 5 or 10)"
    end
  end

  # The `~50% of your 1-min max` cue means "the athlete picks the volume" —
  # only meaningful when each exercise gets its OWN minute (single-exercise
  # EMOM, or alternating 2-ex EMOM where M1=A, M2=B, M3=A, …). A 2-exercise
  # EMOM without `alternating: true` renders as "both each minute" (each
  # exercise gets ~30s, the cue's 1-min framing doesn't apply). When we see
  # the cue on a 2-ex non-alternating EMOM, promote it to alternating and
  # strip any fixed metrics the LLM may have stacked alongside the cue —
  # the cue and explicit metrics are mutually exclusive.
  EMOM_CUE_PATTERN     = /~\s*50\s*%[^\n]*?1.?min/i.freeze
  EMOM_CUE_METRIC_KEYS = %w[reps distance_m calories duration_s].freeze

  def fix_emom_alternating_inference(section, idx)
    return unless section["format"] == "emom"
    return if section["alternating"]

    exercises = Array(section["exercises"])
    return unless exercises.size == 2
    return unless exercises.any? { |ex| ex["notes"].to_s.match?(EMOM_CUE_PATTERN) }

    section["alternating"] = true
    @fixes << "EMOM '#{section["name"]}': set alternating: true (the '~50% of 1-min max' cue implies each exercise gets its own minute)"

    exercises.each do |ex|
      next unless ex["notes"].to_s.match?(EMOM_CUE_PATTERN)
      stripped = EMOM_CUE_METRIC_KEYS.select { |k| ex.delete(k) }
      next if stripped.empty?
      @fixes << "EMOM '#{section["name"]}': stripped #{stripped.join(', ')} from '#{ex["name"]}' (incompatible with the 1-min max cue)"
    end
  end

  # Continuous circuit: duration_mins must be a multiple of exercise count
  # (one exercise fills each minute, cycling through the list).
  def fix_continuous_circuit_structure(section, idx)
    exercises = Array(section["exercises"])
    n = exercises.size
    return if n.zero?
    dur = section["duration_mins"].to_i
    return if dur.zero? || (dur % n).zero?
    snapped = ((dur.to_f / n).ceil * n)
    section["duration_mins"] = snapped
    section.delete("notes") # LLM notes often contain stale fractional round calculations
    @fixes << "Continuous Circuit '#{section["name"]}': duration_mins #{dur} → #{snapped} (must be multiple of #{n} exercises)"
  end

  # Tabata exercises must be a factor of 8: 1, 2, 4, or 8.
  # Each exercise fills 8/n rounds. Truncates to nearest valid count (never pads).
  TABATA_VALID_COUNTS = [ 1, 2, 4, 8 ].freeze

  def fix_tabata_exercise_count(section, idx)
    exercises = Array(section["exercises"])
    n = exercises.size
    return if TABATA_VALID_COUNTS.include?(n)

    snapped = TABATA_VALID_COUNTS.select { |v| v <= n }.last || 1
    section["exercises"] = exercises.first(snapped)
    @fixes << "Tabata '#{section["name"]}': #{n} exercises → #{snapped} (must be 1, 2, 4, or 8)"
  end

  # Tabata is always exactly 4 minutes: 20s on + 10s off × 8 rounds = 240s.
  def fix_tabata_duration(section, idx)
    return if section["duration_mins"] == 4
    old = section["duration_mins"]
    section["duration_mins"] = 4
    @fixes << "Tabata '#{section["name"]}': corrected duration #{old} → 4 mins"
  end

  # Per-exercise rung-count parity: when overrides are present, every exercise
  # in a ladder/mountain must produce the same number of rungs as the section
  # default. Mismatched overrides are stripped (the section falls back to its
  # defaults) — the alternative ("drop the offending exercise") loses real
  # programming intent and was explicitly ruled out in the design.
  def fix_ladder_rung_count_parity(section, idx)
    return unless Workout::LadderSequence.has_per_exercise_overrides?(section)

    exercises   = Array(section["exercises"])
    rung_counts = exercises.map { |ex| Workout::LadderSequence.values_for(section, ex).size }
    return if rung_counts.uniq.size == 1

    exercises.each do |ex|
      %w[varies start end step peak].each { |k| ex.delete(k) }
    end
    @warnings << "Ladder '#{section["name"]}': per-exercise rung counts mismatched (#{rung_counts.join(",")}) — stripped overrides, falling back to section defaults"
  end

  # Ladder/mountain: step size must be within the valid range for the varying metric.
  # Snaps up to the minimum if too small, down to the maximum if too large.
  # Mountain sections need an end value — default to start if missing
  def fix_mountain_end(section)
    sv = section["start"].to_i
    ev = section["end"].to_i
    return if ev > 0

    section["end"] = sv
    @fixes << "Mountain '#{section["name"]}': end value missing — set to #{sv} (mirrors start)"
  end

  def fix_ladder_step(section, idx)
    fix_ladder_step_for(section, section["name"], section)
    Array(section["exercises"]).each do |ex|
      next unless ex["step"].present? && ex["varies"].present?
      fix_ladder_step_for(section, "#{section["name"]} / #{ex["name"]}", ex)
    end
  end

  # Snap `target`'s step into bounds for its varies (target is a section or exercise hash).
  def fix_ladder_step_for(section, label, target)
    varies = target["varies"]
    step   = target["step"].to_f
    return unless varies && step > 0

    min = LADDER_STEP_MIN[varies]
    max = LADDER_STEP_MAX[varies]  # nil means no upper bound
    return unless min  # unknown metric — skip

    corrected = if step < min
      min
    elsif max && step > max
      max
    else
      return  # already valid
    end

    target["step"] = corrected
    @fixes << "#{section["format"].capitalize} '#{label}': " \
              "step #{step} invalid for #{varies} — corrected to #{corrected}"
  end

  # Clean mountain presets — curated sequences that look and feel right.
  # The validator snaps ugly step-1 mountains (peak > 5) to the nearest preset.
  MOUNTAIN_PRESETS = [
    { total: 16,  start: 1, peak: 4,  step: 1 },  # 1,2,3,4,3,2,1
    { total: 25,  start: 1, peak: 5,  step: 1 },  # 1,2,3,4,5,4,3,2,1
    { total: 45,  start: 5, peak: 15, step: 5 },  # 5,10,15,10,5
    { total: 50,  start: 2, peak: 10, step: 2 },  # 2,4,6,8,10,8,6,4,2
    { total: 75,  start: 3, peak: 15, step: 3 },  # 3,6,9,12,15,12,9,6,3
    { total: 80,  start: 5, peak: 20, step: 5 },  # 5,10,15,20,15,10,5
    { total: 90,  start: 9, peak: 18, step: 3 },  # 9,12,15,18,15,12,9
    { total: 125, start: 5, peak: 25, step: 5 }  # 5,10,15,20,25,20,15,10,5
  ].freeze

  # Mountain rep sequences with step 1 and a peak above 5 produce ugly, drawn-out
  # sequences (8,9,10,11,12,11,10,9,8). Snap to the nearest clean preset.
  # Step 1 with peak ≤ 5 is fine (Bear Complex: 1,2,3,4,5,4,3,2,1).
  # Step 2+ is always fine.
  def fix_mountain_rep_sequence(sections)
    sections.each do |section|
      next unless section["format"] == "mountain"
      next unless section["varies"].to_s == "reps"
      next unless section["step"].to_i == 1

      sv = section["start"].to_i
      pk = section["peak"].to_i
      ev = section["end"].to_i.nonzero? || sv
      next if pk <= 5  # small mountains with step 1 are fine

      # Calculate current total reps per exercise
      up = sv.step(pk, 1).to_a
      dn = (pk - 1).step(ev, -1).to_a
      current_total = (up + dn).sum

      # Find nearest preset
      preset = MOUNTAIN_PRESETS.min_by { |p| (p[:total] - current_total).abs }
      next unless preset

      old_seq = "#{sv}→#{pk}→#{ev} step 1"
      section["start"] = preset[:start]
      section["peak"]  = preset[:peak]
      section["end"]   = preset[:start]
      section["step"]  = preset[:step]

      new_up = preset[:start].step(preset[:peak], preset[:step]).to_a
      new_dn = (preset[:peak] - preset[:step]).step(preset[:start], -preset[:step]).to_a
      new_seq = (new_up + new_dn).join(",")
      @fixes << "Mountain '#{section["name"]}': ugly sequence (#{old_seq} = #{current_total} reps) → #{new_seq} (#{preset[:total]} reps)"
    end
  end

  # For-time sections with multiple exercises and fewer than 3 rounds are not a
  # meaningful conditioning block — bump to 3 rounds. Single-exercise for_time
  # (e.g. 100 cal row for time) is fine with 1 round.
  def fix_for_time_rounds(sections)
    sections.each do |section|
      next unless section["format"] == "for_time"
      next if Array(section["exercises"]).size <= 1
      next if section["rounds"].to_i >= 3
      old = section["rounds"].to_i
      section["rounds"] = 3
      @fixes << "For-time '#{section["name"]}': rounds #{old} → 3 (multi-exercise for_time needs multiple rounds)"
    end
  end

  # Snap rep and calorie counts to "clean" numbers — even numbers or multiples of 5.
  # Odd, awkward counts like 13 or 7 are artefacts of scaling and look wrong in a workout.
  # Only applies to values >= 4; leaves small counts (1, 2, 3) untouched.
  # Does not touch weight_kg, distance_m, or duration_s.
  def fix_clean_rep_counts(sections)
    sections.each do |section|
      Array(section["exercises"]).each do |ex|
        %w[reps calories].each do |field|
          val = ex[field].to_i
          next if val < 4
          clean = nearest_clean_rep(val)
          next if clean == val
          ex[field] = clean
          @fixes << "'#{ex["name"]}' in '#{section["name"]}': #{field} #{val} → #{clean} (snapped to clean number)"
        end
      end
    end
  end

  # Preferred rep counts: these are the numbers athletes actually use.
  # We snap to the nearest preferred number first; fall back to any even/mult-of-5.
  PREFERRED_REPS = [ 5, 6, 8, 10, 12, 15, 16, 18, 20, 25, 30, 40, 50 ].freeze
  BANNED_REPS    = [ 7, 9, 11, 13, 17, 19 ].freeze

  def nearest_clean_rep(n)
    return n if !BANNED_REPS.include?(n) && (n % 2 == 0 || n % 5 == 0)
    # Find nearest preferred number
    best = PREFERRED_REPS.min_by { |v| (v - n).abs }
    # If preferred is too far (>5 away), fall back to nearest even/mult-of-5
    if (best - n).abs > 5
      down = (n - 1).downto([ n - 5, 1 ].max).find { |v| v % 2 == 0 || v % 5 == 0 }
      up   = (n + 1).upto(n + 5).find { |v| v % 2 == 0 || v % 5 == 0 }
      best = [ down, up ].compact.min_by { |v| (v - n).abs }
    end
    best
  end

  # Snap distance_m to clean round numbers.
  # Treadmill/running: multiples of 100 (e.g. 180m → 200m).
  # Everything else: multiples of 50, occasionally 25 (e.g. 125m stays, 180m → 200m).
  RUNNING_PATTERN = /treadmill|run|jog|sprint/i

  def fix_clean_distances(sections)
    sections.each do |section|
      Array(section["exercises"]).each do |ex|
        val = ex["distance_m"].to_i
        next if val <= 0

        if ex["name"].to_s.match?(RUNNING_PATTERN)
          clean = nearest_clean_distance(val, 100)
        else
          clean = nearest_clean_distance(val, 25)
        end
        next if clean == val

        ex["distance_m"] = clean
        @fixes << "'#{ex["name"]}' in '#{section["name"]}': distance #{val}m → #{clean}m (snapped to round number)"
      end
    end
  end

  def nearest_clean_distance(n, step)
    return n if (n % step).zero?
    down = (n / step) * step
    up   = down + step
    # Prefer the closer one; tie goes up
    (n - down) <= (up - n) ? down : up
  end

  # Treadmills don't have calorie counters in the way bikes/rowers do.
  # Convert calories to distance (~20m per cal — a rough treadmill estimate).
  # 15 cal ≈ 300m, 25 cal ≈ 500m. Snapped to nearest 100m.
  TREADMILL_PATTERN_STRICT = /\btreadmill\b/i.freeze
  TREADMILL_CAL_TO_DISTANCE_M = 20

  def fix_treadmill_calories(sections)
    sections.each do |section|
      Array(section["exercises"]).each do |ex|
        next unless ex["name"].to_s.match?(TREADMILL_PATTERN_STRICT)
        next unless ex["calories"].to_i > 0

        cals = ex["calories"].to_i
        distance = nearest_clean_distance(cals * TREADMILL_CAL_TO_DISTANCE_M, 100)
        ex["distance_m"] = distance
        ex.delete("calories")
        @fixes << "'#{section["name"]}': treadmill #{cals} cal → #{distance}m (treadmills use distance, not calories)"
      end
    end
  end

  # When the user's available equipment excludes treadmill, swap any running /
  # treadmill exercise the LLM emitted for the user's preferred cardio machine
  # (Row > SkiErg > Air Bike, by availability). Activity-agnostic — applies
  # equally to Deka Mile (running headline) and any other activity that allows
  # running. Distance/duration metrics are left intact; downstream validators
  # handle metric normalization per machine.
  def user_has_no_treadmill?
    @available_equipment.is_a?(Array) && @available_equipment.any? && !@available_equipment.include?("treadmill")
  end

  def fix_swap_run_for_no_treadmill(sections)
    replacement = RUN_REPLACEMENTS.find { |r| @available_equipment.include?(r[:slug]) }
    return unless replacement

    sections.each do |section|
      Array(section["exercises"]).each do |ex|
        name = ex["name"].to_s
        next unless name.match?(CARDIO_RUN_PATTERN) || name.match?(TREADMILL_PATTERN_STRICT)

        ex["name"]      = replacement[:name]
        ex["equipment"] = replacement[:slug]
        @fixes << "'#{section["name"]}': swapped '#{name}' for '#{replacement[:name]}' (user has no treadmill)"
      end
    end
  end

  # Any non-exempt section with rounds missing/zero is almost certainly a mistake.
  # - Single-exercise sections with < 3 rounds → 3 rounds
  # - Any section with rounds completely absent (nil) → 3 rounds (LLM forgot to set it)
  # - Unknown/invalid formats get normalised to "rounds"
  # Skips warm-up, cool-down, tabata, emom, amrap, for_time, ladder, mountain.
  SINGLE_SET_EXEMPT   = %w[straight tabata emom continuous_circuit amrap for_time ladder mountain matrix hundred switchback].freeze
  KNOWN_FORMATS       = %w[straight rounds tabata emom continuous_circuit amrap for_time ladder mountain matrix hundred switchback].freeze
  ABS_PILATES_PATTERN     = /abs|core|pilates|hundred/i

  # A `format: rounds` section with a single exercise whose `duration_s` is
  # 10 minutes or longer is almost always the LLM trying to express a
  # continuous zone 2 cardio block but defaulting to rounds. Multiplying
  # the duration by the round count blows the session budget (e.g.
  # `3 rounds × Run 24min` = 72 min of cardio in a 60-min session).
  # Convert to `format: straight` with a single round.
  # Deka Mile rule: compromised runs are STRICTLY ≤ 300m (the race format is
  # 10 × 160m, training up to 300m builds the engine, longer than that drifts
  # away from race specificity). Any exercise named "Compromised Run" with a
  # distance_m above 300 gets clamped to 300m.
  def fix_deka_mile_compromised_run_cap(sections)
    cap = 300
    sections.each do |section|
      is_ladder = %w[ladder mountain].include?(section["format"])

      Array(section["exercises"]).each do |ex|
        next unless ex["name"].to_s.match?(/\Acompromised run\z/i)

        if is_ladder
          clamp_compromised_run_ladder(section, ex, cap)
        else
          dist = ex["distance_m"].to_i
          next if dist <= cap || dist.zero?
          ex["distance_m"] = cap
          @fixes << "Deka Mile '#{section["name"]}' #{ex["name"]}: #{dist}m → #{cap}m (compromised run cap)"
        end
      end
    end
  end

  # When the compromised run is inside a ladder, clamp whichever scale owns it
  # (section default OR per-exercise override) so the max rung ≤ cap.
  def clamp_compromised_run_ladder(section, exercise, cap)
    target =
      if exercise["start"].present? || exercise["end"].present? || exercise["peak"].present?
        exercise
      elsif Workout::LadderSequence.varies_for(section, exercise) == "distance_m"
        section
      else
        return
      end

    values = Workout::LadderSequence.values_for(section, exercise)
    max_value = values.map(&:to_i).max
    return if max_value <= cap

    scale = cap.to_f / max_value
    %w[start end peak].each do |key|
      next unless target[key]
      step = target["step"].to_f.nonzero? || 1.0
      snapped = ((target[key].to_f * scale) / step).round * step
      target[key] = snapped.to_i.clamp(step.to_i, cap)
    end

    label = target.equal?(section) ? section["name"] : "#{section["name"]} / #{exercise["name"]}"
    @fixes << "Deka Mile '#{label}' compromised run ladder: max rung #{max_value}m → ≤#{cap}m (compromised run cap)"
  end

  def fix_long_cardio_rounds_to_straight(sections)
    sections.each do |section|
      next unless section["format"] == "rounds"
      exercises = Array(section["exercises"])
      next unless exercises.size == 1

      ex = exercises.first
      dur_s = ex["duration_s"].to_i
      next if dur_s < 600 # under 10 min per round is plausible interval work

      original_rounds = section["rounds"].to_i
      section["format"] = "straight"
      section["duration_mins"] = (dur_s / 60.0).round
      section.delete("rounds")
      section.delete("rest_secs")
      @fixes << "'#{section["name"]}': #{original_rounds} rounds × #{dur_s}s cardio → straight (one #{section["duration_mins"]} min block)"
    end
  end

  def fix_single_set_sections(sections)
    sections.each do |section|
      next if %w[warm_up cool_down].include?(section["category"])
      next if section["name"].to_s.match?(ABS_PILATES_PATTERN)

      fmt = section["format"].to_s

      # Normalise unknown formats to "rounds" so the view renders properly
      unless fmt.in?(KNOWN_FORMATS)
        @fixes << "'#{section["name"]}': unknown format '#{fmt}' → rounds"
        section["format"] = "rounds"
        fmt = "rounds"
      end

      next if fmt.in?(SINGLE_SET_EXEMPT)

      rounds = section["rounds"]
      if rounds.nil? || rounds.to_i.zero?
        # Rounds completely absent — default to 3
        section["rounds"] = 3
        @fixes << "'#{section["name"]}': rounds missing → set to 3"
      elsif rounds.to_i < 3 && Array(section["exercises"]).size == 1
        # Single exercise with duration_s is a timed block (e.g. 8-min treadmill fartlek) — 1 round is fine
        ex = Array(section["exercises"]).first
        next if ex && (ex["duration_s"].to_i > 0 || section["duration_mins"].to_i > 0)
        # Single exercise, too few rounds
        section["rounds"] = 3
        @fixes << "'#{section["name"]}': single exercise with #{rounds} round(s) → 3 rounds"
      end
    end
  end

  # AMRAP with fewer than 3 exercises is nonsensical — you'd just repeat the same
  # movement continuously. Convert to for_time (rounds: 3) which makes more sense.
  def fix_amrap_minimum_exercises(sections)
    sections.each do |section|
      next unless section["format"] == "amrap"
      exercises = Array(section["exercises"])
      next if exercises.size >= 3

      duration = section["duration_mins"]
      section["format"] = "for_time"
      section["rounds"] = 3
      section.delete("duration_mins")
      @fixes << "'#{section["name"]}': AMRAP with #{exercises.size} exercise(s) → converted to 3 rounds for_time"
    end
  end

  # AMRAP and EMOM durations should be clean round numbers.
  CLEAN_TIMED_DURATIONS = [ 4, 6, 8, 10, 12, 15, 16, 18, 20, 24, 30 ].freeze

  def fix_timed_section_durations(sections)
    sections.each do |section|
      next unless section["format"].in?(%w[amrap emom])
      dur = section["duration_mins"].to_i
      next if dur <= 0 || CLEAN_TIMED_DURATIONS.include?(dur)

      clean = CLEAN_TIMED_DURATIONS.min_by { |v| (v - dur).abs }
      section["duration_mins"] = clean
      @fixes << "'#{section["name"]}': #{section["format"].upcase} duration #{dur} min → #{clean} min (snapped to clean number)"
    end
  end

  # Detect programming hidden in exercise notes (e.g. "5 × 60m sprints with 45s rest")
  # and promote it to actual structure fields (rounds, distance_m, rest_secs).
  HIDDEN_ROUNDS_PATTERN = /(\d+)\s*[×x]\s*(\d+)\s*(m|reps?|cal)\b/i.freeze
  HIDDEN_REST_PATTERN   = /(\d+)\s*(?:s|sec|seconds?)\s*(?:rest|recovery|easy|glid)/i.freeze
  # Catches "Repeat × 5", "repeat x 5", "× 5 rounds" etc buried in notes
  REPEAT_PATTERN        = /repeat\s*[×x]\s*(\d+)|[×x]\s*(\d+)\s*(?:rounds?|times?)?/i.freeze

  # Jump rope cannot track calories — convert to reps
  # Bear Complex: ensure a description is present — many athletes won't know the movement
  # Strength exercises in rounds format with moderate reps should have weight guidance
  STRENGTH_WEIGHT_CUE = "Working weight \u2014 last 2 reps should feel challenging but doable".freeze
  BODYWEIGHT_PATTERN = /push.?up|pull.?up|burpee|sit.?up|plank|crunch|lunge|squat(?!.*bar)|pike|dip|mountain.?climb/i.freeze

  def fix_strength_weight_cues(sections)
    sections.each do |section|
      next unless section["format"] == "rounds"
      next unless section["rounds"].to_i >= 3
      next if %w[warm_up cool_down].include?(section["category"])

      Array(section["exercises"]).each do |ex|
        next if ex["notes"].present? && ex["notes"].length > 10
        next if ex["reps"].to_i.zero? || ex["reps"].to_i > 15
        next if ex["name"].to_s.match?(BODYWEIGHT_PATTERN)
        next if ex["calories"] || ex["distance_m"] || ex["duration_s"]

        ex["notes"] = STRENGTH_WEIGHT_CUE
      end
    end
  end

  # Race-relative phrasing ("race weight", "competition load") only makes
  # sense on actual race-station exercises. The LLM frequently puts it on
  # strength accessories like Deadlift, which aren't in any race — so we
  # replace those phrases with absolute language.
  RACE_WEIGHT_DETECT = /\brace weight\b|\bcompetition (?:sled|load|weight)\b/i.freeze
  RACE_WEIGHT_REPLACEMENTS = [
    [ /\bheavier than race weight\b/i,    "heavy strength load" ],
    [ /\bwell below race weight\b/i,      "light load" ],
    [ /\bbelow race weight\b/i,           "submaximal load" ],
    [ /\babove race weight\b/i,           "near-max load" ],
    [ /\bat race weight\b/i,              "working load" ],
    [ /\babove competition load\b/i,      "near-max load" ],
    [ /\bfull competition sled\b/i,       "heavy sled" ],
    [ /\bHyrox competition sled\b/i,      "heavy sled" ],
    [ /\bHyrox competition load\b/i,      "near-max load" ],
    [ /\bcompetition sled\b/i,            "heavy sled" ],
    [ /\bcompetition weight\b/i,          "working weight" ],
    [ /\bcompetition load\b/i,            "working weight" ],
    [ /\brace weight\b/i,                 "working weight" ]
  ].freeze

  def fix_race_weight_on_non_stations(sections)
    activity = LLMContext::Activities.for(@main_tag_slug)
    return unless activity
    return unless activity.const_defined?(:RACE_STATIONS)

    station_pattern = build_race_station_pattern(activity::RACE_STATIONS)

    sections.each do |section|
      Array(section["exercises"]).each do |ex|
        note = ex["notes"].to_s
        next if note.empty?
        next unless note.match?(RACE_WEIGHT_DETECT)
        next if ex["name"].to_s.match?(station_pattern)

        new_note = note.dup
        RACE_WEIGHT_REPLACEMENTS.each { |pattern, replacement| new_note.gsub!(pattern, replacement) }
        next if new_note == note

        ex["notes"] = new_note
        @fixes << "'#{ex["name"]}' in '#{section["name"]}': replaced race-relative wording (not a race station)"
      end
    end
  end

  def build_race_station_pattern(stations)
    parts = Array(stations).map { |s| Regexp.escape(s.to_s) }
    Regexp.new("\\b(?:#{parts.join('|')})", Regexp::IGNORECASE)
  end

  BEAR_PATTERN = /\bbears?\b/i.freeze
  BEAR_NOTES = "Power Clean \u2192 Front Squat \u2192 Push Press \u2192 Back Squat \u2192 Behind-the-neck Push Press. Heavy barbell \u2014 each rep should feel challenging by the peak.".freeze

  def fix_bear_complex_notes(sections)
    sections.each do |section|
      Array(section["exercises"]).each do |ex|
        name = ex["name"].to_s
        # Match "Bear" or "Bears" but not "Bear Crawl"
        next unless name.match?(BEAR_PATTERN) && !name.match?(/crawl/i)
        next if ex["notes"].present? && ex["notes"].length > 20

        ex["notes"] = BEAR_NOTES
        @fixes << "'#{name}' in '#{section["name"]}': added Bear Complex description"
      end
    end
  end

  JUMP_ROPE_PATTERN = /jump\s*rope|skipping\s*rope|skip\s*rope/i.freeze

  def fix_jump_rope_calories(sections)
    sections.each do |section|
      Array(section["exercises"]).each do |ex|
        next unless ex["name"].to_s.match?(JUMP_ROPE_PATTERN)
        next unless ex["calories"].to_i > 0

        cals = ex["calories"]
        ex["reps"] = cals
        ex.delete("calories")
        @fixes << "'#{ex["name"]}' in '#{section["name"]}': converted #{cals} cal → #{cals} reps (jump rope has no calorie counter)"
      end
    end
  end

  # Strip distances, durations, and programming descriptors from exercise names.
  # The LLM sometimes generates names like "Rower 1000m Single", "SkiErg 30s Sprint",
  # "Assault Bike 15 cal Blast". The name should just be the equipment/movement.
  EXERCISE_NAME_JUNK = /\s+\d+\s*(?:m|km|s|sec|min|cal|calories|reps?)\b.*$/i.freeze
  EXERCISE_NAME_DESCRIPTOR = /\s+(?:single|couplet|triplet|ladder|pyramid|interval|sprint|repeat|blast|piece|set)\s*$/i.freeze
  EXERCISE_NAME_HARD_EASY = /\s+(?:hard|easy|recovery|threshold|steady|all.out)[\s\/]*(?:easy|recovery|interval|effort)?.*$/i.freeze

  def fix_exercise_name_programming(sections)
    sections.each do |section|
      Array(section["exercises"]).each do |ex|
        original = ex["name"].to_s
        cleaned = original
          .sub(EXERCISE_NAME_JUNK, "")
          .sub(EXERCISE_NAME_DESCRIPTOR, "")
          .sub(EXERCISE_NAME_HARD_EASY, "")
          .strip
        next if cleaned == original || cleaned.empty?
        ex["name"] = cleaned
        @fixes << "'#{section["name"]}': exercise name '#{original}' → '#{cleaned}' (stripped embedded programming)"
      end
    end
  end

  def fix_notes_as_programming(sections)
    sections.each do |section|
      next if %w[warm_up cool_down].include?(section["category"])
      Array(section["exercises"]).each do |ex|
        notes = ex["notes"].to_s

        # Check for "Repeat × N" pattern — extract rounds and clean notes
        if notes.match?(REPEAT_PATTERN) && !notes.match?(HIDDEN_ROUNDS_PATTERN)
          rmatch = notes.match(REPEAT_PATTERN)
          repeat_val = (rmatch[1] || rmatch[2]).to_i
          if repeat_val >= 2 && section["rounds"].to_i <= 1
            section["rounds"] = repeat_val
            ex["notes"] = notes.sub(REPEAT_PATTERN, "").sub(/\.\s*$/, "").strip
            ex.delete("notes") if ex["notes"].empty?
            @fixes << "'#{section["name"]}': extracted #{repeat_val} rounds from 'Repeat × #{repeat_val}' in notes"
          end
          next
        end

        next unless notes.match?(HIDDEN_ROUNDS_PATTERN)

        match = notes.match(HIDDEN_ROUNDS_PATTERN)
        rounds_val = match[1].to_i
        metric_val = match[2].to_i
        metric_unit = match[3].downcase

        next unless rounds_val >= 2 && metric_val > 0

        # Promote to structure
        if section["rounds"].to_i <= 2
          section["rounds"] = rounds_val
          @fixes << "'#{section["name"]}': extracted #{rounds_val} rounds from notes"
        end

        case metric_unit
        when "m"
          ex["distance_m"] = metric_val unless ex["distance_m"].to_i > 0
        when /rep/
          ex["reps"] = metric_val unless ex["reps"].to_i > 0
        when "cal"
          ex["calories"] = metric_val unless ex["calories"].to_i > 0
        end

        # Extract rest if present
        if (rest_match = notes.match(HIDDEN_REST_PATTERN))
          rest_val = rest_match[1].to_i
          section["rest_secs"] = rest_val if rest_val > 0 && section["rest_secs"].to_i.zero?
          @fixes << "'#{section["name"]}': extracted #{rest_val}s rest from notes"
        end

        # Clean the programming out of notes, keep any remaining coaching cues
        cleaned = notes.sub(/\d+\s*[×x]\s*\d+\s*(?:m|reps?|cal)\b[^.]*(?:\.\s*)?/i, "").strip
        cleaned = cleaned.sub(/\d+\s*(?:s|sec|seconds?)\s*(?:rest|recovery|easy|glid)\w*[^.]*(?:\.\s*)?/i, "").strip
        if cleaned.empty?
          ex.delete("notes")
        else
          ex["notes"] = cleaned
        end
        @fixes << "'#{section["name"]}': promoted hidden programming from '#{ex["name"]}' notes to structure"
      end
    end
  end

  # Snaps rest_secs to the nearest allowed value: 30, 45, or 60.
  # Any rest longer than 60s is capped at 60; anything below 30 stays as-is (short transitions are fine).
  ALLOWED_REST            = [ 30, 45, 60 ].freeze
  ALLOWED_REST_MAX_EFFORT = [ 90, 120, 150, 180 ].freeze

  def fix_rest_secs(sections)
    sections.each do |section|
      rest = section["rest_secs"].to_i
      next if rest.zero? || rest <= 20  # no rest or very short transition — leave alone

      # High-intensity sections (heavy lifts, sprint intervals) need long rest.
      # Snap to the wider 90/120/150/180 grid; never coerce to 60s.
      allowed = section["intensity_style"] == "high" ? ALLOWED_REST_MAX_EFFORT : ALLOWED_REST
      snapped = allowed.min_by { |v| (v - rest).abs }
      next if snapped == rest
      @fixes << "'#{section["name"]}': rest_secs #{rest}s → #{snapped}s"
      section["rest_secs"] = snapped
    end
  end

  # Caps rest_secs so it never exceeds the working duration of a single round.
  # Only applies to sections whose work is clearly timed (every exercise has a duration_s).
  # Rep-based and calorie-based work is left alone — their work duration isn't measurable here.
  # Tabata's 20s/10s is defined by the format, not rest_secs — skip it.
  def fix_rest_ratio(sections)
    sections.each do |section|
      next if section["format"] == "tabata"
      # high-intensity sections deliberately have long rest (heavy lifts, sprint
      # intervals) — rest > work is the point.
      next if section["intensity_style"] == "high"
      rest = section["rest_secs"].to_i
      next if rest.zero?

      exercises = Array(section["exercises"])
      next if exercises.empty?
      next unless exercises.all? { |ex| ex["duration_s"].to_i > 0 }

      work_secs = exercises.sum { |ex| ex["duration_s"].to_i }
      next if rest <= work_secs

      @fixes << "'#{section["name"]}': rest_secs #{rest}s → #{work_secs}s (rest cannot exceed #{work_secs}s work)"
      section["rest_secs"] = work_secs
    end
  end

  # Alternating/unilateral exercises must have even rep counts so both sides get equal work.
  # Rounds up odd counts by 1 rather than down, so volume is never reduced.
  # Skips ladder/mountain sections — those use progressive rep schemes where odd numbers are fine.
  def fix_alternating_reps(sections)
    sections.each do |section|
      next if section["format"].in?(%w[ladder mountain])
      Array(section["exercises"]).each do |exercise|
        next unless exercise["name"]&.match?(ALTERNATING_PATTERN)
        reps = exercise["reps"].to_i
        next if reps.zero? || reps.even?
        exercise["reps"] = reps + 1
        @fixes << "'#{exercise["name"]}' in '#{section["name"]}': reps #{reps} → #{reps + 1} (alternating — must be even)"
      end
    end
  end


  # Tabata is 20s work / 10s rest — the interval is the constraint, not reps or calories.
  # Strip reps and calories from all tabata exercises; keep weight_kg and distance_m.
  def fix_tabata_exercise_metrics(sections)
    sections.each do |section|
      next unless section["format"] == "tabata"
      Array(section["exercises"]).each do |ex|
        stripped = []
        %w[reps calories distance_m].each do |field|
          if ex[field].present?
            stripped << "#{field}: #{ex[field]}"
            ex.delete(field)
          end
        end
        next if stripped.empty?
        @fixes << "Tabata '#{section["name"]}': removed #{stripped.join(", ")} from '#{ex["name"]}' — 20s burst, no metric needed"
      end
    end
  end

  # Tabata exercises often get notes like "20s on / 10s off × 8 rounds" from the LLM.
  # This is already shown in the UI under each exercise name — strip it from notes to avoid duplication.
  def fix_tabata_exercise_notes(sections)
    sections.each do |section|
      next unless section["format"] == "tabata"
      Array(section["exercises"]).each do |exercise|
        next unless exercise["notes"].present?
        exercise.delete("notes")
        @fixes << "'#{exercise["name"]}' in '#{section["name"]}': removed tabata interval notes (shown in UI)"
      end
    end
  end

  # Strip parenthetical timing/format info from tabata exercise names.
  # The LLM sometimes generates names like "Air Squat (tabata—20s work)" or
  # "Push-up (20s on/10s off)" — the UI already shows tabata timing.
  def fix_tabata_exercise_names(sections)
    sections.each do |section|
      next unless section["format"] == "tabata"
      Array(section["exercises"]).each do |exercise|
        original = exercise["name"].to_s
        cleaned = original.sub(/\s*\(.*(?:tabata|20s|10s|work|rest|on.off|burst).*\)\s*$/i, "").strip
        next if cleaned == original || cleaned.empty?
        exercise["name"] = cleaned
        @fixes << "Tabata '#{section["name"]}': cleaned exercise name '#{original}' → '#{cleaned}'"
      end
    end
  end

  # Strip ladder/mountain sequence descriptions from exercise notes.
  # The UI now shows "40 cal → 45 cal → 50 cal → 55 cal → 60 cal" in the metric
  # line, so notes like "40 cal → 45 cal → 50 cal..." are redundant.
  def fix_ladder_exercise_notes(sections)
    sections.each do |section|
      next unless %w[ladder mountain].include?(section["format"])
      Array(section["exercises"]).each do |exercise|
        next unless exercise["notes"].present?
        # Strip leading sequence patterns like "40 cal → 45 cal → 50 cal..."
        cleaned = exercise["notes"]
          .sub(/\A\d+\s*(?:cal|reps|kg|m|s)\s*(?:→|->|,)\s*(?:\d+\s*(?:cal|reps|kg|m|s)\s*(?:→|->|,)\s*)*\d+\s*(?:cal|reps|kg|m|s)\.?\s*/i, "")
          .strip
        if cleaned != exercise["notes"]
          if cleaned.empty?
            exercise.delete("notes")
          else
            exercise["notes"] = cleaned
          end
          @fixes << "Ladder '#{section["name"]}': stripped sequence from '#{exercise["name"]}' notes (shown in metric)"
        end
      end
    end
  end

  # Ensure ladder/mountain sections have rest_between_rungs set.
  # Athletes need recovery between rungs — default to 45s if missing.
  def fix_ladder_rest(sections)
    sections.each do |section|
      next unless %w[ladder mountain].include?(section["format"])
      next if section["rest_between_rungs"].to_i > 0
      section["rest_between_rungs"] = 45
      @fixes << "Ladder '#{section["name"]}': added rest_between_rungs: 45s"
    end
  end

  # Treadmill exercises in ladder format are wrong if `varies` is anything but
  # `distance_m`. The LLM often emits speed-ladder shapes (start/end values that
  # look like km/h) — we rescue those by reshaping into a proper distance ladder.
  # Incline ladders (small values + incline language) are converted to a straight
  # block with athlete-relative effort cues.
  TREADMILL_PATTERN = /treadmill|pace.?build|fartlek|speed.?ladder|climb|jog|run|incline/i.freeze
  INCLINE_PATTERN   = /incline|climb|hill|gradient/i.freeze

  def fix_treadmill_ladder(sections)
    sections.each do |section|
      next unless %w[ladder mountain].include?(section["format"])
      # Parallel-rung ladders: if a treadmill exercise already carries its own
      # distance_m override, the ladder is intentionally a mixed-metric shape.
      # Leave the whole section alone — the rewrite below would destroy it.
      if Array(section["exercises"]).any? { |ex|
        ex["name"].to_s.match?(TREADMILL_PATTERN) && ex["varies"].to_s == "distance_m"
      }
        next
      end
      # If the ladder is already a clean distance ladder, leave it alone.
      next if section["varies"].to_s == "distance_m"

      exercises = Array(section["exercises"])
      is_treadmill = section["name"].to_s.match?(TREADMILL_PATTERN) ||
                     exercises.any? { |ex| ex["name"].to_s.match?(TREADMILL_PATTERN) }
      next unless is_treadmill

      sv = section["start"].to_f; ev = section["end"].to_f
      step = [ section["step"].to_f, 1.0 ].max

      vals = []
      if section["format"] == "ladder"
        v = sv; if sv <= ev; while v <= ev + 0.001; vals << v; v += step; end; else; while v >= ev - 0.001; vals << v; v -= step; end; end
      else
        pk = section["peak"].to_f
        v = sv; while v <= pk + 0.001; vals << v; v += step; end
        v = pk - step; while v >= ev - 0.001; vals << v; v -= step; end
      end
      vals = vals.map { |v| v == v.to_i ? v.to_i : v }

      is_incline = section["name"].to_s.match?(INCLINE_PATTERN) ||
                   exercises.any? { |ex| ex["name"].to_s.match?(INCLINE_PATTERN) } ||
                   (vals.max <= 15 && vals.first <= 5)

      if is_incline
        vals = vals.map { |v| [ v, 15 ].min }
        total_mins = vals.size * 2
        total_secs = total_mins * 60
        pace_note = "#{vals.first}%→#{vals.last}% incline · 1 min at each grade with 1 min flat (0%) between · steady hard effort throughout"
        ex_name = "Treadmill Incline Intervals"

        section["format"] = "straight"
        section["duration_mins"] = total_mins
        section.delete("rounds")
        %w[start end step peak varies rest_between_rungs rest_secs].each { |k| section.delete(k) }

        first_ex = exercises.first
        first_ex["name"] = ex_name
        first_ex["duration_s"] = total_secs
        %w[reps calories distance_m weight_kg].each { |k| first_ex.delete(k) }
        first_ex["notes"] = pace_note
        section["exercises"] = [ first_ex ]

        @fixes << "'#{section["name"]}': treadmill incline ladder → straight (#{vals.join(" → ")}%, #{total_mins} min)"
      else
        # Speed-ladder shape — reshape as a DISTANCE ladder so it renders properly
        # and the prompt-level absolute-speed ban isn't violated.
        clamped_start = (vals.first.to_i / 100.0).round * 100
        clamped_end   = (vals.last.to_i  / 100.0).round * 100
        clamped_start = clamped_start.clamp(100, 800)
        clamped_end   = clamped_end.clamp(100, 800)
        # Need at least 3 rungs (100m apart). If not, default to 400→100m.
        if (clamped_start - clamped_end).abs < 200 || clamped_start == clamped_end
          clamped_start = 400
          clamped_end   = 100
        end

        section["format"] = "ladder"
        section["varies"] = "distance_m"
        section["start"]  = clamped_start
        section["end"]    = clamped_end
        section["step"]   = 100
        section["rest_between_rungs"] = section["rest_between_rungs"].to_i.nonzero? || 60
        section.delete("rounds")
        section.delete("peak")
        section.delete("rest_secs")

        first_ex = exercises.first
        first_ex["name"] = "Run"
        first_ex["equipment"] = "treadmill"
        %w[reps calories distance_m weight_kg duration_s notes].each { |k| first_ex.delete(k) }
        section["exercises"] = [ first_ex ]

        @fixes << "'#{section["name"]}': treadmill speed ladder → distance ladder (#{clamped_start}→#{clamped_end}m, step 100)"
      end
    end
  end

  # Deka Atlas: convert barbell push press → DB push press at race weights.
  # The event is entirely dumbbell-based — barbell push press is never correct.
  ATLAS_DB_PRESS_WEIGHT = 17.5

  def fix_atlas_barbell_press(sections)
    return unless @main_tag_slug == "deka-atlas"
    sections.each do |section|
      Array(section["exercises"]).each do |ex|
        next unless ex["name"].to_s.match?(/push\s*press.*barbell|barbell.*push\s*press|strict\s*press.*barbell|barbell.*strict\s*press|overhead\s*press.*barbell|barbell.*overhead\s*press/i)
        old_name = ex["name"]
        ex["name"] = "DB Push Press"
        ex["weight_kg"] = ATLAS_DB_PRESS_WEIGHT
        @fixes << "'#{section["name"]}': #{old_name} → DB Push Press at #{ex["weight_kg"]}kg (Deka Atlas = dumbbells only)"
      end
    end
  end

  # Cap overhead pressing weights at sensible maximums for conditioning work.
  # Even strong athletes shouldn't be push pressing 60kg+ in a circuit context.
  OHP_WEIGHT_CAP = 40
  OHP_PATTERN = /push\s*press|strict\s*press|overhead\s*press|shoulder\s*press|jerk/i.freeze

  def fix_overhead_weight_cap(sections)
    cap = OHP_WEIGHT_CAP
    sections.each do |section|
      Array(section["exercises"]).each do |ex|
        next unless ex["name"].to_s.match?(OHP_PATTERN)
        next unless ex["weight_kg"].to_f > cap
        old_weight = ex["weight_kg"]
        ex["weight_kg"] = cap
        @fixes << "'#{section["name"]}': #{ex["name"]} #{old_weight}kg → #{cap}kg (overhead cap)"
      end
    end
  end

  # When section notes and an exercise's notes say the same thing, remove the
  # duplicate from whichever is less specific. For single-exercise sections,
  # keep the exercise notes (shown inline) and clear the section notes.
  def fix_duplicate_section_exercise_notes(sections)
    sections.each do |section|
      next unless section["notes"].present?
      exercises = Array(section["exercises"])
      exercises.each do |ex|
        next unless ex["notes"].present?
        sec_note = section["notes"].to_s.strip.downcase
        ex_note  = ex["notes"].to_s.strip.downcase
        if sec_note == ex_note || sec_note.include?(ex_note) || ex_note.include?(sec_note)
          section.delete("notes")
          @fixes << "'#{section["name"]}': removed duplicate section notes (already on exercise)"
          break
        end
      end
    end
  end

  # Strip leading "N sets of N reps at Xkg" sentences from section notes — that
  # information is already shown structurally in the section header and exercise rows.
  REDUNDANT_NOTE_PATTERN = /\A\d+\s+sets?\s+of\s+\d+[^.]*\.\s*/i

  def fix_redundant_section_notes(sections)
    sections.each do |section|
      next unless section["notes"].present?
      cleaned = section["notes"].sub(REDUNDANT_NOTE_PATTERN, "").strip
      next if cleaned == section["notes"]
      if cleaned.empty?
        section.delete("notes")
      else
        section["notes"] = cleaned
      end
      @fixes << "'#{section["name"]}': stripped redundant set/rep restatement from section notes"
    end
  end

  # The Hundred: exactly 1 exercise with exactly 100 reps, done for time.
  # Trims to 1 exercise if multiple were given; corrects reps to 100.
  def fix_hundred(section, idx)
    exercises = Array(section["exercises"])
    if exercises.size > 1
      section["exercises"] = exercises.first(1)
      @fixes << "Hundred '#{section["name"]}': trimmed to 1 exercise (was #{exercises.size})"
    end
    if section["rounds"].to_i > 1
      section.delete("rounds")
      @fixes << "Hundred '#{section["name"]}': removed rounds (single all-out effort)"
    end
    ex = Array(section["exercises"]).first
    return unless ex

    # Cardio machines should use calories: 100, not reps: 100
    if ex["name"].to_s.match?(CARDIO_MACHINE_PATTERN)
      if ex["reps"].to_i > 0
        ex["calories"] = 100
        ex.delete("reps")
        @fixes << "Hundred '#{section["name"]}': #{ex["name"]} is a cardio machine — reps → calories: 100"
      elsif ex["calories"].to_i != 100
        old = ex["calories"]
        ex["calories"] = 100
        @fixes << "Hundred '#{section["name"]}': calories #{old} → 100"
      end
    else
      unless ex["reps"].to_i == 100
        old = ex["reps"]
        ex["reps"] = 100
        @fixes << "Hundred '#{section["name"]}': reps #{old} → 100"
      end
    end
  end

  # FM: strip any section whose name looks like an activation/mobility warm-up block.
  # These don't belong in Functional Muscle — warm-up is cardio machine only.
  FM_ACTIVATION_PATTERN = /activation|mobility|prep|dynamic warm|movement prep/i.freeze

  def fix_fm_remove_activation(sections)
    removed = sections.select { |s| s["name"].to_s.match?(FM_ACTIVATION_PATTERN) }
    removed.each do |s|
      sections.delete(s)
      @fixes << "FM: removed activation/mobility block '#{s["name"]}' — FM warm-up is cardio only"
    end
  end

  # Rotating EMOM exercises fill the full minute — reps, calories, distance, and duration
  # must not be set. Also strip notes that are just minute-assignment labels (e.g. "Min 1, 3, 5:").
  # These are redundant — exercises just rotate in order; the athlete doesn't need minute callouts.
  EMOM_NOTE_JUNK = /\A\s*min(?:ute)?s?\s+[\d,\s]+[:–\-]/i.freeze
  # Notes that just restate the EMOM structure: "12 cal row, remaining time rest. Repeat × 10 minutes"
  EMOM_RESTATE_PATTERN = /\d+\s*(?:cal|reps?|m)\s+\w+[^.]*remain\w*\s+time\s+rest[^.]*\.?\s*/i.freeze
  EMOM_REPEAT_PATTERN  = /repeat\s*[×x]\s*\d+\s*min\w*\.?\s*/i.freeze

  def fix_continuous_circuit_exercise_metrics(sections)
    sections.each do |section|
      next unless section["format"] == "continuous_circuit"
      Array(section["exercises"]).each do |ex|
        stripped = []

        %w[reps calories distance_m duration_s].each do |field|
          if ex[field].present?
            stripped << "#{field}: #{ex[field]}"
            ex.delete(field)
          end
        end

        # Strip minute-assignment prefix from notes (e.g. "Min 1, 3, 5, 7: explosive snatch")
        if ex["notes"].to_s.match?(EMOM_NOTE_JUNK)
          cleaned = ex["notes"].sub(EMOM_NOTE_JUNK, "").strip.sub(/\A[,.\s]+/, "").strip
          if cleaned.present?
            ex["notes"] = cleaned
          else
            ex.delete("notes")
          end
          stripped << "minute-assignment note"
        end

        next if stripped.empty?
        @fixes << "Continuous Circuit '#{section["name"]}': cleaned '#{ex["name"]}' (#{stripped.join(", ")})"
      end
    end
  end

  # Strip notes on ANY EMOM exercise that just restate the structure
  # (e.g. "Minute 1: 12 cal row, remaining time rest. Repeat × 10 minutes")
  def fix_emom_notes(sections)
    sections.each do |section|
      next unless section["format"] == "emom"
      Array(section["exercises"]).each do |ex|
        notes = ex["notes"].to_s
        next if notes.blank?

        cleaned = notes
        cleaned = cleaned.sub(EMOM_NOTE_JUNK, "").strip.sub(/\A[,.\s]+/, "").strip
        cleaned = cleaned.sub(EMOM_RESTATE_PATTERN, "").strip
        cleaned = cleaned.sub(EMOM_REPEAT_PATTERN, "").strip

        next if cleaned == notes

        if cleaned.empty?
          ex.delete("notes")
        else
          ex["notes"] = cleaned
        end
        @fixes << "EMOM '#{section["name"]}': stripped restated programming from '#{ex["name"]}' notes"
      end
    end
  end

  # Cardio intervals: if the LLM split a hard/easy protocol into two exercises
  # on the same machine (e.g. "Ski Erg Sprint" + "Ski Erg Recovery"), merge them
  # back into one exercise and remove rest_secs.
  def fix_cardio_interval_split(sections)
    sections.each do |section|
      next unless section["format"] == "rounds"
      exercises = Array(section["exercises"])

      # Case 1: LLM split hard/easy into two exercises on the same machine — merge
      if exercises.size == 2
        names = exercises.map { |e| e["name"].to_s }
        machines = names.map { |n| n.match(CARDIO_MACHINE_PATTERN)&.to_s&.downcase }
        if machines[0].present? && machines[0] == machines[1]
          notes = exercises.map { |e| (e["notes"].to_s + " " + e["name"].to_s).downcase }
          hard_idx = notes.index { |n| n.match?(/hard|sprint|max|effort|explosive/) }
          easy_idx = notes.index { |n| n.match?(/easy|recovery|rest|light|slow/) }
          if hard_idx && easy_idx && hard_idx != easy_idx
            hard = exercises[hard_idx]
            dur = hard["duration_s"].to_i
            if dur > 0
              hard["notes"] = "#{dur}s hard / #{exercises[easy_idx]["duration_s"] || dur}s easy"
              hard["name"] = hard["name"].sub(/\s*(sprint|hard|effort|max)/i, "").strip
              section["exercises"] = [ hard ]
              section.delete("rest_secs")
              @fixes << "Cardio intervals '#{section["name"]}': merged split hard/easy into single exercise"
              next
            end
          end
        end
      end

      # Case 2: Single-exercise cardio interval with built-in recovery — strip rest_secs
      if exercises.size == 1
        ex = exercises.first
        notes = ex["notes"].to_s
        if ex["name"].to_s.match?(CARDIO_MACHINE_PATTERN) &&
           notes.match?(/hard.*easy|all.out.*easy|effort.*easy|recovery.*built|easy.*recovery.*built/i) &&
           section["rest_secs"].to_i > 0
          section.delete("rest_secs")
          @fixes << "Cardio intervals '#{section["name"]}': removed rest_secs (recovery is built into the set)"
        end
      end
    end
  end

  # Threshold cardio intervals (e.g. "35s hard / 25s easy") should use clean
  # splits that add to a round minute. Snap duration_s to the hard portion and
  # rewrite notes to match. Also fix duration_s set to the total (hard+easy)
  # instead of just the hard portion.
  CLEAN_THRESHOLD_SPLITS = [ [ 15, 15 ], [ 20, 10 ], [ 30, 30 ], [ 40, 20 ], [ 45, 15 ] ].freeze
  INTERVAL_HARD_WORDS = /(?:hard|sprint|all.out|max|effort|explosive|power)/i.freeze
  INTERVAL_EASY_WORDS = /(?:easy|rest|recovery|active|slow|light)/i.freeze
  INTERVAL_NOTES_PATTERN = /(\d+)\s*(?:s|sec(?:ond)?s?)\s*#{INTERVAL_HARD_WORDS}[^\/;,]*[\/;,]\s*(\d+)\s*(?:s|sec(?:ond)?s?)\s*#{INTERVAL_EASY_WORDS}/i.freeze

  def fix_threshold_interval_duration(sections)
    sections.each do |section|
      next unless section["format"] == "rounds"
      exercises = Array(section["exercises"])
      next unless exercises.size == 1

      ex = exercises.first
      next unless ex["name"].to_s.match?(CARDIO_MACHINE_PATTERN)
      notes = ex["notes"].to_s

      # Match hard/easy interval patterns in notes. The LLM writes these many ways:
      #   "30s hard / 30s easy", "45 seconds all-out; 20 seconds easy recovery",
      #   "40s hard effort / 20s easy", "20s max / 10s rest"
      m = notes.match(INTERVAL_NOTES_PATTERN)
      next unless m

      hard = m[1].to_i
      easy = m[2].to_i
      total = hard + easy

      # Fix 1: duration_s set to total (hard+easy) instead of just hard
      if ex["duration_s"].to_i == total && hard != total
        ex["duration_s"] = hard
        @fixes << "'#{section["name"]}': duration_s #{total}s → #{hard}s (hard portion only, easy is recovery)"
      end

      # Fix 2: odd split — snap to nearest clean preset
      unless CLEAN_THRESHOLD_SPLITS.include?([ hard, easy ])
        best = CLEAN_THRESHOLD_SPLITS.min_by { |h, e| (h - hard).abs + (e - easy).abs }
        ex["duration_s"] = best[0]
        ex["notes"] = "#{best[0]}s hard / #{best[1]}s easy"
        @fixes << "'#{section["name"]}': snapped interval to #{best[0]}s hard / #{best[1]}s easy (was #{hard}s/#{easy}s)"
      end
    end
  end

  # Cardio machines (bike, rower, ski erg) must have a metric — calories, distance,
  # or duration. If none is set, default to calories based on the section context.
  DEFAULT_CARDIO_CALS = { 1 => 25, 2 => 20, 3 => 15 }.freeze # by round count bucket

  def fix_cardio_missing_metric(sections)
    sections.each do |section|
      next if %w[emom continuous_circuit].include?(section["format"]) # each minute is the metric
      rounds = section["rounds"].to_i.clamp(1, 99)

      Array(section["exercises"]).each do |ex|
        name = ex["name"].to_s
        is_machine = name.match?(CARDIO_MACHINE_PATTERN) && !name.match?(/\btreadmill\b/i)
        is_run     = name.match?(CARDIO_RUN_PATTERN) || name.match?(/\btreadmill\b/i)
        next unless is_machine || is_run

        has_metric = ex["reps"].to_i > 0 || ex["calories"].to_i > 0 ||
                     ex["distance_m"].to_i > 0 || ex["duration_s"].to_i > 0
        next if has_metric

        if is_run
          # Default running rounds to 1km per round — a sensible zone-2 default.
          ex["distance_m"] = 1000
          @fixes << "'#{section["name"]}': #{name} had no metric — set 1000m"
        else
          bucket = rounds <= 3 ? 1 : rounds <= 6 ? 2 : 3
          cals = DEFAULT_CARDIO_CALS[bucket]
          ex["calories"] = cals
          @fixes << "'#{section["name"]}': #{name} had no metric — set #{cals} cal"
        end
      end
    end
  end

  # Cardio machines never take `reps` — convert to the right metric.
  # Row/Ski/Bike → calories. Treadmill → duration_s. Bare "Row" is excluded
  # because it's commonly a strength exercise (DB Row, Bent-Over Row, Inverted Row).
  CARDIO_REPS_TO_CAL = /\b(rowing\s*machine|rower|ski.?erg|skierg|assault\s*bike|echo\s*bike|air\s*bike|fan\s*bike)\b/i.freeze
  CARDIO_REPS_TO_DURATION = /\btreadmill\b/i.freeze

  def fix_cardio_machine_reps(sections)
    sections.each do |section|
      Array(section["exercises"]).each do |ex|
        next unless ex["reps"].to_i > 0
        next if ex["calories"].to_i > 0 || ex["distance_m"].to_i > 0 || ex["duration_s"].to_i > 0

        name = ex["name"].to_s
        if name.match?(CARDIO_REPS_TO_CAL)
          ex["calories"] = ex["reps"]
          ex.delete("reps")
          @fixes << "'#{section["name"]}' / '#{name}': converted reps→calories (cardio machines never take reps)"
        elsif name.match?(CARDIO_REPS_TO_DURATION)
          ex["duration_s"] = ex["reps"]
          ex.delete("reps")
          @fixes << "'#{section["name"]}' / '#{name}': converted reps→duration_s (treadmill never takes reps)"
        end
      end
    end
  end

  # Strip absolute speed/pace/power references the LLM occasionally injects
  # despite the prompt ban. Renames "Speed Ladder" / "Speed Pyramid" sections,
  # and deletes section/exercise notes containing the banned patterns.
  ABSOLUTE_SPEED_PATTERN = %r{\d+(?:\.\d+)?\s*(?:km/h|mph|w\b|spm|rpm)|\d+:\d+\s*/\s*(?:km|mile)\b}i.freeze
  SPEED_LADDER_NAME = /\bspeed\s+(ladder|pyramid)\b/i.freeze

  def fix_speed_language(sections)
    sections.each do |section|
      name = section["name"].to_s
      if name.match?(SPEED_LADDER_NAME)
        original = name.dup
        section["name"] = name.gsub(SPEED_LADDER_NAME) { "Distance #{$1.capitalize}" }
        @fixes << "Renamed '#{original}' → '#{section["name"]}' (speed ladders are banned — use distance/duration)"
      end

      if section["notes"].to_s.match?(ABSOLUTE_SPEED_PATTERN)
        @fixes << "'#{section["name"]}' notes stripped (contained absolute speed/pace/power)"
        section.delete("notes")
      end

      Array(section["exercises"]).each do |ex|
        ex_name = ex["name"].to_s
        if ex_name.match?(SPEED_LADDER_NAME)
          original = ex_name.dup
          ex["name"] = ex_name.gsub(SPEED_LADDER_NAME) { "Distance #{$1.capitalize}" }
          @fixes << "'#{section["name"]}' / '#{original}' renamed to '#{ex["name"]}' (speed ladder banned)"
        end

        if ex["notes"].to_s.match?(ABSOLUTE_SPEED_PATTERN)
          @fixes << "'#{section["name"]}' / '#{ex["name"]}' notes stripped (contained absolute speed/pace/power)"
          ex.delete("notes")
        end
      end
    end
  end

  # Detect 2-exercise sections that look like switchback intent (one cal-cardio
  # paired with one rep-based floor movement, with section name suggesting up-and-
  # down) and convert to format: switchback so the renderer shows the proper
  # descending/ascending sequence under each exercise. Without this the LLM
  # often emits format: rounds with single values, which renders as a flat couplet.
  SWITCHBACK_NAME_HINT = /\bup\s*(?:and|&|n)\s*(?:back|down)\b|\bswitch.?back\b|\bup.?down\b/i.freeze
  CAL_CARDIO_PATTERN   = /\b(rower|rowing\s*machine|ski\s*erg|skierg|assault\s*bike|echo\s*bike|air\s*bike|fan\s*bike)\b/i.freeze

  # Ladder, mountain, and switchback formats derive per-rung values from the
  # section-level `start`/`end`/`step` fields. Per-exercise `reps`/`calories`/
  # `distance_m`/`duration_s` are ignored by the renderer but make the JSON
  # look conflicting and confuse anyone editing the data. Strip them so the
  # section-level values are the single source of truth.
  def fix_ladder_switchback_strip_metrics(sections)
    sections.each do |section|
      next unless %w[ladder mountain switchback].include?(section["format"])
      Array(section["exercises"]).each do |ex|
        stripped = []
        %w[reps calories distance_m duration_s weight_kg].each do |key|
          next unless ex.key?(key) && ex[key]
          stripped << "#{key}=#{ex[key]}"
          ex.delete(key)
        end
        if stripped.any?
          @fixes << "#{section["format"].capitalize} '#{section["name"]}' / '#{ex["name"]}': stripped per-exercise #{stripped.join(", ")} (derived from section start/end/step)"
        end
      end
    end
  end

  def fix_switchback_inference(sections)
    sections.each do |section|
      next if section["format"] == "switchback"
      next unless section["name"].to_s.match?(SWITCHBACK_NAME_HINT)
      exercises = Array(section["exercises"])
      next unless exercises.size == 2

      cardio_idx = exercises.find_index { |ex| ex["name"].to_s.match?(CAL_CARDIO_PATTERN) && ex["calories"].to_i > 0 }
      floor_idx  = exercises.find_index { |ex| ex["reps"].to_i > 0 }
      next unless cardio_idx && floor_idx && cardio_idx != floor_idx

      cardio = exercises[cardio_idx]
      floor  = exercises[floor_idx]

      # Switchback: cardio side counts down, floor side counts up.
      # Use the larger of the two as the start; smaller as the end.
      hi = [ cardio["calories"].to_i, floor["reps"].to_i ].max
      lo = [ cardio["calories"].to_i, floor["reps"].to_i ].min
      step = case hi - lo
      when 0..0 then 5
      when 1..15 then 5
      else 5
      end
      # Snap to multiples of 5 and ensure ≥3 rungs.
      hi = (hi / 5.0).round * 5
      lo = (lo / 5.0).round * 5
      hi = 25 if hi < 15 || hi == lo
      lo = 5  if lo < 5  || hi == lo
      lo = hi - (step * 4) if (hi - lo) < step * 2

      # Reorder exercises so cardio is first (descending side per the schema).
      ordered = [ cardio, floor ]
      # Strip baked-in single values — switchback derives them from start/end/step.
      %w[reps calories distance_m duration_s].each do |k|
        ordered.each { |ex| ex.delete(k) }
      end

      section["format"] = "switchback"
      section["start"]  = hi
      section["end"]    = lo
      section["step"]   = step
      section["exercises"] = ordered
      section.delete("rounds")
      section.delete("rest_secs")

      @fixes << "'#{section["name"]}': inferred switchback (#{hi}→#{lo}, step #{step}) from up-and-back pattern"
    end
  end

  # Turbine sessions: fix formats and ensure sensible round counts.
  # - Convert for_time to rounds (Turbine blocks are always interval or steady-state)
  # - Ensure distance repeats have at least 4 rounds
  MIN_TURBINE_DISTANCE_ROUNDS = 4

  def fix_turbine_formats(sections)
    sections.each do |section|
      next unless section["category"] == "main"

      # Convert for_time to rounds — Turbine is always intervals or steady-state
      if section["format"] == "for_time"
        section["format"] = "rounds"
        section["rounds"] = [ section["rounds"].to_i, 4 ].max
        @fixes << "Turbine '#{section["name"]}': converted for_time to rounds"
      end

      # Ensure distance repeats have enough rounds
      exercises = Array(section["exercises"])
      if section["format"] == "rounds" && exercises.size == 1 && exercises.first["distance_m"].to_i > 0
        if section["rounds"].to_i < MIN_TURBINE_DISTANCE_ROUNDS
          old_rounds = section["rounds"].to_i
          section["rounds"] = MIN_TURBINE_DISTANCE_ROUNDS
          @fixes << "Turbine '#{section["name"]}': increased rounds from #{old_rounds} to #{MIN_TURBINE_DISTANCE_ROUNDS} for distance repeats"
        end
      end
    end
  end

  # Turbine sessions: cap each main block to ~12 min of working time.
  # Zone 2 / steady-state blocks must be rounds: 1 (one continuous effort).
  # Any block with rounds × duration exceeding 12 min gets trimmed.
  MAX_TURBINE_BLOCK_SECS = 12 * 60

  def fix_turbine_block_durations(sections)
    sections.each do |section|
      next unless section["category"] == "main"
      exercises = Array(section["exercises"])
      next if exercises.empty?

      rounds = section["rounds"].to_i
      rounds = 1 if rounds < 1

      # Steady-state detection: single exercise with long duration and no hard/easy notes
      if exercises.size == 1
        ex = exercises.first
        dur = ex["duration_s"].to_i
        notes = ex["notes"].to_s

        # Zone 2 / steady state — force rounds: 1
        if dur >= 300 && !notes.match?(/hard.*easy|sprint|max effort/i)
          if rounds > 1
            section["rounds"] = 1
            @fixes << "Turbine '#{section["name"]}': capped steady-state to 1 round (was #{rounds})"
            rounds = 1
          end
          # Cap duration to 12 min
          if dur > MAX_TURBINE_BLOCK_SECS
            ex["duration_s"] = MAX_TURBINE_BLOCK_SECS
            @fixes << "Turbine '#{section["name"]}': capped duration to 12 min (was #{dur / 60} min)"
          end
        end
      end

      # General check: total working time across rounds
      total_work = exercises.sum { |e| e["duration_s"].to_i } * rounds
      rest_total = section["rest_secs"].to_i * [ rounds - 1, 0 ].max
      total_secs = total_work + rest_total

      if total_secs > MAX_TURBINE_BLOCK_SECS && rounds > 1
        # Reduce rounds to fit
        new_rounds = rounds
        while new_rounds > 1
          new_rounds -= 1
          t = exercises.sum { |e| e["duration_s"].to_i } * new_rounds + section["rest_secs"].to_i * [ new_rounds - 1, 0 ].max
          break if t <= MAX_TURBINE_BLOCK_SECS
        end
        section["rounds"] = new_rounds
        @fixes << "Turbine '#{section["name"]}': reduced rounds from #{rounds} to #{new_rounds} to fit 12-min block cap"
      end
    end
  end


  # Hyrox does NOT use Assault Bike / Air Bike. The only cardio machines are
  # SkiErg, Rowing Machine, and Treadmill. Replace any bike references.
  HYROX_BIKE_PATTERN = /assault\s*bike|air\s*bike/i.freeze
  HYROX_CARDIO_REPLACEMENTS = [ "SkiErg", "Rowing Machine", "Treadmill" ].freeze

  def fix_hyrox_banned_machines(sections)
    used_machines = sections.flat_map { |s| Array(s["exercises"]).map { |e| e["name"].to_s } }
    sections.each do |section|
      Array(section["exercises"]).each do |ex|
        next unless ex["name"].to_s.match?(HYROX_BIKE_PATTERN)

        # Pick a replacement that isn't already heavily used in this workout
        replacement = (HYROX_CARDIO_REPLACEMENTS - used_machines).first || HYROX_CARDIO_REPLACEMENTS.sample
        old_name = ex["name"]
        ex["name"] = replacement
        used_machines << replacement
        @fixes << "'#{section["name"]}': replaced #{old_name} with #{replacement} (not a Hyrox machine)"
      end
    end
  end

  # Iron Engine (kettlebell) is kettlebell-only. Strip any exercise from main/
  # finisher sections whose name doesn't indicate a kettlebell movement (either
  # starts with "KB " or contains "kettlebell"). If a section ends up empty,
  # remove it. Warm-ups and cool-downs are exempt — bodyweight activation and
  # stretching are allowed there.
  KB_EXERCISE_PATTERN = /\A\s*(kb\b|kettlebell\b|double\s+kb\b|gorilla\s+row)/i

  def fix_kettlebell_non_kb_exercises(sections)
    sections.each do |section|
      next unless %w[main finisher].include?(section["category"])
      original = Array(section["exercises"])
      kept = original.reject do |ex|
        name = ex["name"].to_s
        if name.match?(KB_EXERCISE_PATTERN)
          false
        else
          @fixes << "'#{section["name"]}': removed '#{name}' (Iron Engine is kettlebell-only)"
          true
        end
      end
      section["exercises"] = kept
    end

    sections.reject! do |section|
      next false unless %w[main finisher].include?(section["category"])
      if Array(section["exercises"]).empty?
        @fixes << "Removed section '#{section["name"]}' (no kettlebell exercises remained)"
        true
      else
        false
      end
    end
  end

  # Catches sections with different names but identical structure (same format,
  # rounds, and exercises). The LLM sometimes generates "FINAL PUSH" and
  # "DEATH RACE" with the exact same content.
  def dedup_structurally_identical_sections(sections)
    main_finisher = sections.select { |s| %w[main finisher].include?(s["category"]) }
    seen = {}
    main_finisher.each do |s|
      key = [ s["format"],
              s["rounds"].to_i,
              Array(s["exercises"]).map { |e| [ e["name"].to_s.downcase.strip, e["reps"].to_i, e["duration_s"].to_i, e["distance_m"].to_i, e["calories"].to_i ] } ].to_s
      if seen[key]
        sections.delete(s)
        @fixes << "Removed structurally duplicate section '#{s["name"]}' (same as '#{seen[key]}')"
      else
        seen[key] = s["name"]
      end
    end
  end

  # FM continuous circuits (every-2-min [E] block): reps must be multiples of 5, minimum 5 per
  # exercise, and at least 25 total across all exercises. If total < 25, scale up
  # proportionally (preserving ratios) until the minimum is met.
  FM_CIRCUIT_EMOM_MIN_TOTAL = 25

  def fix_fm_continuous_circuit_reps(sections)
    sections.each do |section|
      next unless section["format"] == "continuous_circuit"
      # Only the FM [E] block (exactly 3 exercises) gets the minimum-25 scale-up.
      next unless Array(section["exercises"]).size == 3
      exercises = Array(section["exercises"]).select { |e| e["reps"].to_i > 0 }
      next if exercises.empty?

      # Step 1: snap each to nearest multiple of 5, min 5
      exercises.each do |ex|
        ex["reps"] = [ ((ex["reps"].to_i / 5.0).round * 5), 5 ].max
      end

      # Step 2: enforce minimum total of 25
      total = exercises.sum { |e| e["reps"].to_i }
      if total < FM_CIRCUIT_EMOM_MIN_TOTAL
        # Scale up proportionally, keeping each as a multiple of 5, min 5
        scale = FM_CIRCUIT_EMOM_MIN_TOTAL.to_f / total
        exercises.each do |ex|
          ex["reps"] = [ ((ex["reps"].to_i * scale / 5.0).ceil * 5), 5 ].max
        end
        new_total = exercises.sum { |e| e["reps"].to_i }
        @fixes << "FM circuit EMOM '#{section["name"]}': scaled up reps (total #{total} → #{new_total}, minimum #{FM_CIRCUIT_EMOM_MIN_TOTAL} required)"
      end
    end
  end

  # FM: strength sections (straight/rounds format, not warm-up/cool-down) must be
  # exactly 5 rounds with either 5 or 10 reps. Fix rounds to 5; snap reps to nearest.
  FM_STRENGTH_EXEMPT = %w[tabata emom continuous_circuit amrap for_time ladder mountain matrix hundred].freeze
  FM_VALID_REPS      = [ 5, 10 ].freeze

  def fix_fm_strength_sets(sections)
    sections.each do |section|
      next if section["format"].to_s.in?(FM_STRENGTH_EXEMPT)
      next if %w[warm_up cool_down].include?(section["category"])
      next if section["name"].to_s.match?(ABS_PILATES_PATTERN)

      # Fix rounds to 5
      if section["rounds"].to_i != 5
        old = section["rounds"]
        section["rounds"] = 5
        @fixes << "FM '#{section["name"]}': rounds #{old.inspect} → 5 (Functional Muscle requires 5 rounds)"
      end

      # Snap reps to 5 or 10
      Array(section["exercises"]).each do |ex|
        reps = ex["reps"].to_i
        next if reps.zero?
        next if FM_VALID_REPS.include?(reps)
        snapped = FM_VALID_REPS.min_by { |v| (v - reps).abs }
        ex["reps"] = snapped
        @fixes << "FM '#{ex["name"]}' in '#{section["name"]}': reps #{reps} → #{snapped} (FM only allows 5×5 or 5×10)"
      end
    end
  end

  # FM: remove non-compound exercises from tabata sections.
  # A compound must contain a connector word joining two movements.
  # After removal the tabata exercise count fixer will snap to the next valid count.
  COMPOUND_CONNECTORS = /\band\b|\bwith\b|\bto\b|\binto\b|\b\+\b/i.freeze

  # FM: flag non-compound tabata exercises in the notes so they're visible,
  # but keep them rather than stripping (an empty tabata is worse).
  def fix_fm_tabata_remove_non_compounds(sections)
    sections.each do |section|
      next unless section["format"] == "tabata"
      Array(section["exercises"]).each do |ex|
        next if ex["name"].to_s.match?(COMPOUND_CONNECTORS)
        ex["notes"] = "⚠ Should be a compound movement (e.g. '#{ex["name"]} and Bicep Curl')"
        @warnings << "FM Tabata '#{section["name"]}': '#{ex["name"]}' is not a compound — flagged in notes"
      end
    end
  end

  # FM: collect ALL straight/rounds strength sections and consolidate into exactly
  # two: "Upper Body Strength" and "Lower Body Strength", each with rounds: 5.
  # Splits exercises by lower-body keyword; anything that doesn't match goes upper.
  LOWER_BODY_PATTERN = /squat|lunge|deadlift|romanian|leg press|leg extension|calf|glute|hip|hamstring|step.?up|box jump/i.freeze
  FM_STRENGTH_EXEMPT_FORMATS = %w[tabata emom continuous_circuit amrap for_time ladder mountain matrix hundred switchback].freeze
  FM_STRENGTH_EXEMPT_NAMES   = /warm|cool|stretch|recovery|pilates|abs|core|hundred/i.freeze

  # Only these exercise name patterns are acceptable in FM strength sections.
  FM_UPPER_MACHINE_PATTERN = /low row|lat pull|bench press|shoulder press|chest fly|reverse fly|side raise|front raise/i.freeze
  FM_LOWER_MACHINE_PATTERN = /leg press|leg extension|leg curl|hamstring curl|calf raise|squat|deadlift|lunge/i.freeze

  def fix_fm_merge_strength_sections(sections)
    strength_sections = sections.reject do |s|
      s["format"].to_s.in?(FM_STRENGTH_EXEMPT_FORMATS) ||
        s["name"].to_s.match?(FM_STRENGTH_EXEMPT_NAMES)
    end

    return if strength_sections.empty?

    all_exercises = strength_sections.flat_map { |s| Array(s["exercises"]) }.uniq { |e| e["name"] }
    return if all_exercises.empty?

    # Split into upper and lower — pick ONE exercise each
    lower_exercises = all_exercises.select { |e| e["name"].to_s.match?(LOWER_BODY_PATTERN) }
    upper_exercises = all_exercises.reject { |e| e["name"].to_s.match?(LOWER_BODY_PATTERN) }

    # Prefer machine exercises; fall back to first available if none match.
    # If no lower body exercises exist at all, synthesize a fallback so both sections always appear.
    upper_pick = upper_exercises.find { |e| e["name"].to_s.match?(FM_UPPER_MACHINE_PATTERN) } || upper_exercises.first
    lower_pick = lower_exercises.find { |e| e["name"].to_s.match?(FM_LOWER_MACHINE_PATTERN) } ||
                 lower_exercises.first ||
                 { "name" => %w[Leg\ Press Leg\ Extension Leg\ Curl Squats Lunges].sample, "reps" => 10 }

    # Ensure reps: 10 and add weight guidance
    [ upper_pick, lower_pick ].compact.each do |ex|
      ex["reps"] = 10
      ex["notes"] = "Working weight \u2014 last 2 reps should feel challenging but doable"
    end

    # Remove all existing strength sections
    strength_sections.each { |s| sections.delete(s) }

    # Insert before pilates/abs/cooldown
    insert_at = sections.index { |s| s["name"].to_s.match?(/pilates|abs|hundred|cool|stretch/i) } || sections.size

    new_sections = []
    if upper_pick
      new_sections << {
        "name"      => "Upper Body Strength",
        "category"  => "main",
        "format"    => "rounds",
        "rounds"    => 5,
        "rest_secs" => 60,
        "exercises" => [ upper_pick ]
      }
    end
    if lower_pick
      new_sections << {
        "name"      => "Lower Body Strength",
        "category"  => "main",
        "format"    => "rounds",
        "rounds"    => 5,
        "rest_secs" => 60,
        "exercises" => [ lower_pick ]
      }
    end

    sections.insert(insert_at, *new_sections)
    @fixes << "FM: strength → #{new_sections.map { |s| "'#{s["name"]}': #{Array(s["exercises"]).first["name"]} 5×10" }.join(", ")}"
  end

  # FM: if no abs/core section is present, synthesise one before the cool-down.
  # Rotates through a small pool so fallback workouts have some variety.
  FM_ABS_FALLBACK_POOL = [
    [ { "name" => "Sit-ups", "reps" => 20 }, { "name" => "Leg raises", "reps" => 20 }, { "name" => "Bicycle crunches", "reps" => 30 }, { "name" => "Alternating toe touches", "reps" => 30 } ],
    [ { "name" => "V-ups", "reps" => 25 }, { "name" => "Russian twists", "reps" => 25 }, { "name" => "Overhead crunches", "reps" => 25 }, { "name" => "Flutter kicks", "reps" => 25 } ],
    [ { "name" => "Crunches", "reps" => 25 }, { "name" => "Leg raises", "reps" => 25 }, { "name" => "Plank shoulder taps", "reps" => 25 }, { "name" => "Dead bugs", "reps" => 25 } ]
  ].freeze

  def fix_fm_ensure_abs(sections)
    has_abs = sections.any? { |s| s["name"].to_s.match?(ABS_PILATES_PATTERN) || s["format"] == "hundred" }
    return if has_abs

    exercises = FM_ABS_FALLBACK_POOL.sample
    abs_section = {
      "name"      => "Abs Finisher",
      "category"  => "finisher",
      "format"    => "straight",
      "exercises" => exercises
    }

    insert_at = sections.index { |s| s["name"].to_s.match?(/cool|stretch/i) } || sections.size
    sections.insert(insert_at, abs_section)
    @fixes << "FM: synthesised Abs Finisher (100 reps) — LLM omitted abs section"
  end

  # FM: enforce the metabolic time budget.
  # Fixed sections (warm-up 5 + upper strength 6 + lower strength 6 + abs 5 + cool-down 4) = 26 min.
  # Remaining budget = duration_mins - 26. If metabolic blocks exceed this, remove from the end.
  FM_BLOCK_MINUTES = {
    "tabata"   => 6,
    "mountain" => 10,
    "ladder"   => 12,
    "hundred"  => 5
  }.freeze
  FM_FIXED_MINS = 26

  def fix_fm_trim_metabolic_blocks(sections)
    budget = (@duration_mins || 60) - FM_FIXED_MINS
    return if budget <= 0

    metabolic = sections.reject do |s|
      %w[warm_up cool_down].include?(s["category"]) ||
        s["name"].to_s.match?(ABS_PILATES_PATTERN) ||
        s["name"].to_s.match?(/strength/i)
    end

    total = metabolic.sum { |s| fm_block_estimated_mins(s) }
    return if total <= budget

    while total > budget && metabolic.size > 1
      removed = metabolic.pop
      removed_mins = fm_block_estimated_mins(removed)
      sections.delete(removed)
      total -= removed_mins
      @fixes << "FM time budget: removed '#{removed["name"]}' (#{removed_mins} min) — over #{budget} min metabolic budget"
    end
  end

  def fm_block_estimated_mins(section)
    fmt = section["format"].to_s
    return FM_BLOCK_MINUTES[fmt] if FM_BLOCK_MINUTES.key?(fmt)
    if fmt == "emom"
      dm = section["duration_mins"].to_i
      return dm > 0 ? dm : 10
    end
    10
  end

  # Strip " Machine" suffix from exercise names in FM strength sections.
  def fix_fm_strip_machine_suffix(sections)
    sections.each do |section|
      next unless section["name"].to_s.match?(/strength/i)
      Array(section["exercises"]).each do |exercise|
        original = exercise["name"].to_s
        cleaned  = original.gsub(/\s+machine\b/i, "").strip
        next if cleaned == original
        exercise["name"] = cleaned
        @fixes << "'#{original}' → '#{cleaned}' (stripped Machine suffix)"
      end
    end
  end

  # FM: enforce section order — warm-up → metabolic → upper strength → lower strength → abs → cool-down.
  # Pulls any abs/pilates sections out and reinserts them just before the cool-down.
  def fix_fm_section_order(sections)
    abs_sections = sections.select { |s| s["name"].to_s.match?(ABS_PILATES_PATTERN) || s["format"] == "hundred" }
    return if abs_sections.empty?

    cooldown_idx = sections.index { |s| s["category"] == "cool_down" }
    target_idx   = cooldown_idx || sections.size

    # Check if all abs sections are already just before the cool-down — if so, nothing to do
    abs_indices = abs_sections.map { |s| sections.index(s) }
    expected_start = target_idx - abs_sections.size
    return if abs_indices == (expected_start...(expected_start + abs_sections.size)).to_a

    abs_sections.each { |s| sections.delete(s) }
    # Recalculate insert position after deletion
    new_target = sections.index { |s| s["category"] == "cool_down" } || sections.size
    sections.insert(new_target, *abs_sections)
    @fixes << "FM: moved abs section(s) to just before cool-down"
  end

  # If the LLM generated multiple warm-up-like sections at the start, keep only the first one.
  def dedup_warmup_sections(sections)
    return if sections.size < 2

    # Find all leading sections that look like warm-ups
    leading_warmups = []
    sections.each do |s|
      break unless s["category"] == "warm_up"
      leading_warmups << s
    end

    return if leading_warmups.size <= 1

    # Keep only the first one, remove the rest
    leading_warmups[1..].each do |dupe|
      sections.delete(dupe)
      @fixes << "Removed duplicate warm-up section '#{dupe["name"]}'"
    end
  end

  # If the LLM generated multiple cool-down/stretch sections at the end, keep only the last one.
  def dedup_cooldown_sections(sections)
    return if sections.size < 2

    # Find all trailing sections that look like cool-downs
    trailing_cooldowns = []
    sections.reverse_each do |s|
      break unless s["category"] == "cool_down"
      trailing_cooldowns.unshift(s)
    end

    return if trailing_cooldowns.size <= 1

    # Keep only the last one, remove the rest
    trailing_cooldowns[0..-2].each do |dupe|
      sections.delete(dupe)
      @fixes << "Removed duplicate cool-down section '#{dupe["name"]}'"
    end
  end

  # Remove main/finisher sections that are structurally identical (same name,
  # format, and exercises). The LLM occasionally duplicates a section verbatim.
  def dedup_identical_sections(sections)
    main_finisher = sections.select { |s| %w[main finisher].include?(s["category"]) }
    seen = {}
    main_finisher.each do |s|
      key = [ s["name"].to_s.downcase.strip, s["format"],
              Array(s["exercises"]).map { |e| e["name"].to_s.downcase.strip } ].to_s
      if seen[key]
        sections.delete(s)
        @fixes << "Removed duplicate section '#{s["name"]}'"
      else
        seen[key] = true
      end
    end
  end

  # If the LLM generates too many main sections for the duration, trim from the
  # end so the workout fits. Uses per-format time estimates rather than a flat
  # average, because tabatas (4 min) are much shorter than AMRAPs/rounds (~8-10 min).
  SECTION_TIME_ESTIMATE = {
    "tabata" => 4, "hundred" => 5, "matrix" => 6,
    "ladder" => 6, "mountain" => 6, "switchback" => 8
  }.freeze
  DEFAULT_SECTION_TIME = 8

  def cap_main_section_count(sections)
    main_sections = sections.select { |s| %w[main finisher].include?(s["category"]) }
    return if main_sections.size <= 2

    overhead = 10 # warm-up + cool-down
    budget   = @duration_mins - overhead
    running  = 0
    cutoff   = nil
    changeover = 3 # ~3 min changeover between sections

    main_sections.each_with_index do |s, i|
      est = s["duration_mins"].to_i > 0 ? s["duration_mins"].to_i :
            SECTION_TIME_ESTIMATE[s["format"]] || DEFAULT_SECTION_TIME
      est += changeover if i > 0 # changeover time before each section after the first
      running += est
      if running > budget && i >= 2 # keep at least 2 main sections
        cutoff = i
        break
      end
    end

    return unless cutoff

    main_sections[cutoff..].each do |s|
      sections.delete(s)
      @fixes << "Removed excess section '#{s["name"]}' to fit #{@duration_mins}-min duration"
    end
  end

  # Sync duration mentions in the goal field with actual section durations.
  # The LLM writes the goal before the validator fixes sections, so durations
  # like "10-minute circuit" can be stale after an EMOM snap (10 → 12).
  def fix_goal_durations(sections)
    goal = @data.dig("structure", "goal")
    return unless goal.is_a?(String)

    # Collect actual durations from all timed sections
    actual_durations = sections.filter_map { |s| s["duration_mins"].to_i if s["duration_mins"].to_i > 0 }
    return if actual_durations.empty?

    # Replace any N-minute / N-min mention that doesn't match an actual section
    goal.gsub!(/\b(\d+)[- ](?:minute|min)\b/) do |match|
      mentioned = $1.to_i
      if actual_durations.include?(mentioned)
        match # already correct
      else
        # Find the closest actual duration
        closest = actual_durations.min_by { |d| (d - mentioned).abs }
        (mentioned - closest).abs <= 5 ? match.sub($1, closest.to_s) : match
      end
    end

    @data["structure"]["goal"] = goal
  end

  # Trust the LLM to always include a cool-down as the last section (the prompt
  # requires it). We no longer inject a fallback cool-down, which caused duplicates
  # when the LLM used creative section names. We still clean up the last section's
  # exercises (strip reps/durations, add breath notes) since it should be a stretch.
  def check_cooldown(sections)
    breaths = @duration_mins <= 30 ? 5 : 10
    last = sections.last
    return unless last
    return unless last["category"] == "cool_down"

    Array(last["exercises"]).each do |ex|
      stripped = []
      %w[duration_s reps calories distance_m].each do |field|
        if ex[field].present?
          stripped << field
          ex.delete(field)
        end
      end
      @fixes << "Cool-down: stripped #{stripped.join(", ")} from '#{ex["name"]}'" if stripped.any?

      # Ensure notes contain breaths instruction
      notes = ex["notes"].to_s
      unless notes.match?(/breath/i)
        breath_note = "#{breaths} deep breaths"
        if ex["name"].to_s.match?(/twist|pigeon|flexor|lunge.*stretch|thread|side|single|one.?leg|scorpion/i)
          breath_note = "#{breaths} deep breaths each side"
        end
        ex["notes"] = [ breath_note, notes.presence ].compact.join(". ")
        @fixes << "Cool-down: added '#{breath_note}' to '#{ex["name"]}'"
      end
    end
  end

  # The first section is always the warm-up — ensure it uses format: straight
  # with no rounds. We trust the LLM to always include a warm-up (the prompt
  # requires it) so we no longer inject a fallback row warm-up, which caused
  # duplicates when the LLM used creative section names.
  def fix_warmup_format(sections)
    warmup = sections.find { |s| s["category"] == "warm_up" }
    return unless warmup

    if warmup["format"] != "straight"
      old_format = warmup["format"]
      warmup["format"] = "straight"
      @fixes << "Warm-up format #{old_format} → straight"
    end

    if warmup["rounds"].to_i > 0
      warmup.delete("rounds")
      @fixes << "Warm-up: removed rounds"
    end
  end
end

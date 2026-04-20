class WorkoutLLMGenerator
  class ContractPromptBuilder
    ROLE_TEXT = "You are an expert personal trainer who writes creative, effective gym workouts."

    WARM_UP_VOCAB = {
      easy_cardio:            "Easy cardio at conversational pace plus \"Dynamic stretches\". Do not list individual stretches.",
      kb_activation:          "Kettlebell halos, light swings, and goblet squats plus \"Dynamic stretches\". No cardio machines.",
      bodyweight_activation:  "Easy bodyweight cardio plus \"Dynamic stretches\". No equipment.",
      flow:                   "Yoga/pilates activation flow woven into the main session."
    }.freeze

    COOL_DOWN_VOCAB = {
      full_body_stretch: "Dynamic stretches covering hips, hamstrings, chest, shoulders, spine.",
      lower_focus:       "Hip flexors, pigeon, quads, hamstrings, spinal twist.",
      upper_focus:       "Chest opener, cross-body shoulder, thread the needle, lat stretch.",
      savasana:          "Longer holds, quiet."
    }.freeze

    GLOBAL_RULES = <<~RULES.strip.freeze
      - rest_secs must never exceed the working duration of any set (tabata's 10s/20s pattern is the only exception).
      - At least 3 different section formats across the session. No two adjacent sections share a format.
      - Exercise `name` fields contain the movement only — no reps, durations, loads, or descriptors.
      - Rep counts are clean numbers (even or multiples of 5).
      - Workout name: punchy, memorable, original. Banned words: Barry's, F45, CrossFit, Hyrox, Deka, Tread & Shred, Metafit.
      - `goal` is one motivational sentence about energy and training effect.
      - Switchback format: cardio side must be a calorie-measuring machine (assault bike, rower, ski erg). Never pair switchback with jump rope, treadmill, or any other non-calorie movement.
    RULES

    def initialize(activity:, duration_mins:, athlete_block:, session_notes: nil, banned_equipment_override: [], contract_override: nil)
      @activity = activity
      @duration_mins = duration_mins
      @athlete_block = athlete_block
      @session_notes = session_notes
      @banned_override = Array(banned_equipment_override)
      @contract_override = contract_override
    end

    def build
      tags = []
      tags << xml(:role, ROLE_TEXT)
      tags << xml(:athlete, @athlete_block)
      tags << xml(:task, "Generate a #{@duration_mins}-minute #{@activity::NAME} session.")
      tags << xml(:contract, contract_block)
      tags << xml(:global_rules, GLOBAL_RULES)
      tags << xml(:session_shape, session_shape_block)
      tags << xml(:examples, examples_block)
      tags << xml(:session_notes, @session_notes) if @session_notes.present?
      tags.join("\n\n")
    end

    private

    def contract
      @contract_override || @activity::CONTRACT
    end

    def banned_equipment
      (Array(contract[:banned_equipment]) + @banned_override).uniq
    end

    def contract_block
      vocab = defined?(@activity::MOVEMENT_VOCABULARY) ? @activity::MOVEMENT_VOCABULARY : nil
      lines = []
      lines << "Activity: #{@activity::NAME} (#{@activity::SLUG})"
      lines << ""
      lines << "PURITY: #{contract[:purity]}"
      lines << "ALLOWED EQUIPMENT: #{Array(contract[:allowed_equipment]).join(', ')}"
      lines << "BANNED EQUIPMENT: #{banned_equipment.join(', ')}"
      lines << "ALLOWED FORMATS: #{Array(contract[:allowed_formats]).join(', ')}"
      lines << "PRIMARY FORMATS: #{Array(contract[:primary_formats]).join(', ')}"
      if contract[:signature_formats].present?
        lines << "SIGNATURE FORMATS (use at least one in most sessions): #{Array(contract[:signature_formats]).join(', ')}"
      end
      lines << "WARM-UP STYLE: #{WARM_UP_VOCAB.fetch(contract[:warm_up])}"
      lines << "COOL-DOWN STYLE: #{COOL_DOWN_VOCAB.fetch(contract[:cool_down])}"
      lines << "FINISHER: #{contract[:finisher]}"
      lines << "CORE SECTION: #{contract[:core]}"
      if vocab
        lines << ""
        lines << "Movement vocabulary:"
        lines << vocab.strip
      end
      if contract[:notes].present?
        lines << ""
        lines << contract[:notes]
      end
      lines.join("\n")
    end

    def session_shape_block
      warm_up_min = @duration_mins <= 30 ? 3 : 5
      cool_down_min = @duration_mins <= 30 ? 2 : 5
      working = @duration_mins - warm_up_min - cool_down_min
      <<~SHAPE.strip
        Warm-up (#{warm_up_min} min) → main sections → Cool-down (#{cool_down_min} min).
        Working time: #{working} min. Do NOT set duration_mins on main sets.
      SHAPE
    end

    def examples_block
      json = JSON.pretty_generate(@activity::EXAMPLES.map { |ex| ex.deep_stringify_keys })
      <<~EX.strip
        Three #{@activity::NAME} workouts that show the quality bar and style. Study structure,
        exercise selection, format variety, and naming. Create something fresh in the same
        spirit — do not copy.

        #{json}
      EX
    end

    def xml(tag, body)
      "<#{tag}>\n#{body.to_s.strip}\n</#{tag}>"
    end
  end
end

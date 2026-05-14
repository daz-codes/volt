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
      full_body_stretch: "Name 4-6 specific stretches in the notes — e.g. pigeon, forward fold, cobra, spinal twist, chest opener, thread the needle. Do NOT write generic phrases like \"cover hips, hamstrings, chest, shoulders, spine\" — list actual stretch names.",
      lower_focus:       "Name 4-6 specific lower-body stretches — e.g. pigeon, couch stretch, hamstring stretch, quad pull, spinal twist, figure-four.",
      upper_focus:       "Name 4-6 specific upper-body stretches — e.g. chest opener, cross-body shoulder, thread the needle, lat stretch, child's pose, wrist roll.",
      savasana:          "Longer holds, quiet. Name the final poses — e.g. supta baddha konasana, legs-up-the-wall, savasana."
    }.freeze

    GLOBAL_RULES_PATH = Rails.root.join("app/llm_context/shared/global_rules.md").freeze
    HYBRID_STYLE_PATH = Rails.root.join("app/llm_context/shared/hybrid_style.md").freeze

    def initialize(activity:, duration_mins:, athlete_block:, session_notes: nil, banned_equipment_override: [], contract_override: nil, intensity_style: nil)
      @activity = activity
      @duration_mins = duration_mins
      @athlete_block = athlete_block
      @session_notes = session_notes
      @banned_override = Array(banned_equipment_override)
      @contract_override = contract_override
      @intensity_style = intensity_style
    end

    def build
      tags = []
      tags << xml(:role, ROLE_TEXT)
      tags << xml(:athlete, @athlete_block)
      tags << xml(:task, "Generate a #{@duration_mins}-minute #{@activity::NAME} session.")
      tags << xml(:contract, contract_block)
      tags << xml(:global_rules, self.class.global_rules)
      tags << xml(:hybrid_style, self.class.hybrid_style) if contract[:hybrid_family]
      tags << xml(:session_shape, session_shape_block)
      tags << xml(:examples, examples_block)
      tags << xml(:intensity_style, intensity_style_block) if @intensity_style.present?
      tags << xml(:session_notes, @session_notes) if @session_notes.present?
      tags.join("\n\n")
    end

    def self.global_rules
      @global_rules ||= File.read(GLOBAL_RULES_PATH).sub(/\A# .*\n+/, "").strip
    end

    def self.hybrid_style
      @hybrid_style ||= File.read(HYBRID_STYLE_PATH).sub(/\A# .*\n+/, "").strip
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
      allowed = Array(contract[:allowed_equipment])
      banned  = banned_equipment
      lines = []
      lines << "Activity: #{@activity::NAME} (#{@activity::SLUG})"
      lines << ""
      lines << "PURITY: #{contract[:purity]}"
      lines << "ALLOWED EQUIPMENT: #{allowed.join(', ')}" if allowed.any?
      lines << "BANNED EQUIPMENT: #{banned.join(', ')}" if banned.any?
      if banned_exercise_terms.any?
        lines << "BANNED EXERCISE NAMES (do not use in any section): #{banned_exercise_terms.join(', ')}"
      end
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

    # Extracts readable terms from the contract's banned_exercise_patterns regexes
    # (e.g. /\bassault bike\b/i → "assault bike") so the LLM sees them in the prompt.
    def banned_exercise_terms
      Array(contract[:banned_exercise_patterns]).map do |pattern|
        pattern.source.gsub(/\\b/, "").gsub(/\s+/, " ").strip
      end.reject(&:empty?)
    end

    def session_shape_block
      return flow_session_shape if contract[:warm_up] == :flow

      warm_up_min = @duration_mins <= 30 ? 3 : 5
      cool_down_min = @duration_mins <= 30 ? 2 : 5
      working = @duration_mins - warm_up_min - cool_down_min
      target_mains = case @duration_mins
                     when 0..30 then "1-2"
                     when 31..45 then "1-2"
                     when 46..60 then "1-3"
                     else "1-4"
                     end
      <<~SHAPE.strip
        Shape: Warm-up (#{warm_up_min} min) → main section(s) → Cool-down (#{cool_down_min} min).
        Total duration: #{@duration_mins} min. Working budget is roughly #{working} min MINUS
        ~3-5 min per transition between adjacent sections for equipment changes and rest.
        Do NOT emit transitions as their own sections or mention them in the output — just
        leave room in the timing budget when sizing the work.
        Target #{target_mains} main section(s). A single long main section is a valid and
        often better shape when the workout is one unbroken effort — chippers, long AMRAPs,
        hero WODs, race simulations, extended metcons. Pick the count the workout calls for,
        not the upper end of the range. Err on the side of fewer, tighter sections —
        workouts consistently run long, so cut a section if in doubt.
        Do NOT set duration_mins on main sets.
      SHAPE
    end

    # Flow sessions (yoga/pilates/mobility) run as one continuous sequence.
    # The session IS the warm-up and cool-down — no separate bookend blocks.
    def flow_session_shape
      <<~FLOW.strip
        Shape: One continuous flowing sequence across the full #{@duration_mins} minutes —
        no separate warm-up or cool-down sections. Open with a gentle activation flow,
        build through the main sequence, and close with longer held poses / savasana.
        Pacing is slow and breath-led throughout. Do NOT emit transitions as their own
        sections. Do NOT set duration_mins on main sets.
      FLOW
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

    # Emits the intensity selection plus the activity's translation of it, when the
    # contract defines one. Without a guide line the LLM falls back on the global
    # rules definition, which is right for cardio/strength but wrong for activities
    # like yoga where "high" means power vinyasa, not max-effort sprints.
    def intensity_style_block
      guide = contract[:intensity_guide]&.dig(@intensity_style.to_sym)
      return @intensity_style.to_s unless guide

      "#{@intensity_style}\n\nFor #{@activity::NAME}, treat `#{@intensity_style}` as: #{guide}"
    end

    def xml(tag, body)
      "<#{tag}>\n#{body.to_s.strip}\n</#{tag}>"
    end
  end
end

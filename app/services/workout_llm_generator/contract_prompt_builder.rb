class WorkoutLLMGenerator
  class ContractPromptBuilder
    ROLE_TEXT = <<~ROLE.strip
      You are a top-level personal trainer specialising in Hyrox, Deka, hybrid race-prep,
      and functional fitness. You write inspiring, creative workouts that athletes look
      forward to — every session should feel like a coach designed it, not a template
      filled in.

      The example workouts you'll see show the quality bar, structural shapes, and naming style.
      Study them — then create something fresh in the same spirit. Do NOT copy them.
      **Surprise the athlete with variety**:
      - Rotate cardio modalities across sessions: run, row, ski, bike (where allowed).
        Don't default to whatever the examples use most.
      - Rotate mobility focus: hips, thoracic spine, ankles, full-body. If recent sessions
        leaned on one area, deliberately pick a different one.
      - Mix modality combinations: an EMOM here, a continuous circuit there, a tabata
        finisher one day, a hundred the next.
      - Pick punchy original section names — never reuse the example names directly.

      **Section naming style**: pick punchy 2-4 word names that VAGUELY FIT the exercise
      being done. A "Born to Run" section should have running in it, not KB Swings. A "Heart
      of Steel" section should have heavy lifting. A "Sweep the Leg" section should have
      lunges. "Highway to the Zone" or "Need for Speed" go on cardio sprints. "Burning Heart"
      / "Hearts on Fire" go on burpees or high-intensity grinders. If the perfect match
      isn't obvious, fall back to an atmospheric gym name (Iron Storm, The Crucible) rather
      than a song title that fights the work.

      Two pools to draw from (also invent your own in the same spirit):

      **80s action-film anthems** (Rocky, Top Gun, Karate Kid, Bloodsport, Over the Top,
      Transformers, Scarface, No Retreat No Surrender, Beverly Hills Cop, Rad):

      Eye of the Tiger · Gonna Fly Now · Hearts on Fire · Burning Heart · No Easy Way Out ·
      Going the Distance · Risin' Up · Thrill of the Fight · Hangin' Tough · Training Montage ·
      Living in America · Danger Zone · Mighty Wings · Take My Breath · Highway to the Zone ·
      Need for Speed · Playing with the Boys · You're the Best · Moment of Truth · Glory of
      Love · Cross My Heart · Sweep the Leg · Crane Kick · Wax On Wax Off · Meet Me Halfway ·
      Winner Takes It All · Fight to Survive · The Touch · Push the Limit · Born to Run ·
      True Survivor · Stand on Your Own · Never Surrender · Thunder in Your Heart · Strike
      First · The Heat Is On · Don't Stop Believin'

      **Gym workhorse names** (atmospheric, exercise-agnostic — pair with the work as needed):

      Iron Lift · The Forge · The Anvil · Hammer Time · Heavy Hands · Iron Storm · Final Boss ·
      Last Stand · Lung Buster · Tip of the Spear · Heart of Steel · The Crucible · No Mercy ·
      Cooked · Gut Check · The Minotaur · Engine Builder · Engine Room · The Furnace · Heavy
      Metal · Ground Zero · Wake the Dead · Death March

      Use a different name for every section in a workout — never repeat. Across sessions,
      rotate so the same names don't appear back to back.

      Be the coach the athlete remembers. Lean into creativity, not pattern repetition.
    ROLE

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

    def initialize(activity:, duration_mins:, athlete_block:, session_notes: nil, banned_equipment_override: [], contract_override: nil, intensity_style: nil, user_activity_name: nil)
      @activity = activity
      @duration_mins = duration_mins
      @athlete_block = athlete_block
      @session_notes = session_notes
      @banned_override = Array(banned_equipment_override)
      @contract_override = contract_override
      @intensity_style = intensity_style
      @user_activity_name = user_activity_name.presence
    end

    def build
      tags = []
      tags << xml(:role, ROLE_TEXT)
      tags << xml(:athlete, @athlete_block)
      tags << xml(:task, "Generate a #{@duration_mins}-minute #{@user_activity_name || @activity::NAME} session.")
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
      if (sub_line = run_substitution_line(allowed, banned))
        lines << sub_line
      end
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

    # When the user has no treadmill but the activity allows running, tell the
    # LLM explicitly which cardio machine to substitute. Without this the LLM
    # often still emits Compromised Run for running-headline activities like
    # Deka Mile because the "no treadmill" hint feels detachable from the
    # named exercise. Mirrors validator's fix_swap_run_for_no_treadmill.
    CARDIO_SUBSTITUTION_NAMES = {
      "rowing_machine" => "Row",
      "ski_erg"        => "SkiErg",
      "assault_bike"   => "Air Bike"
    }.freeze

    def run_substitution_line(allowed, banned)
      return nil unless banned.include?("treadmill") && allowed.include?("treadmill")
      available_cardio = %w[rowing_machine ski_erg assault_bike] & allowed - banned
      return nil if available_cardio.empty?
      names = available_cardio.map { |slug| CARDIO_SUBSTITUTION_NAMES.fetch(slug) }
      pref = names.first
      "RUNNING SUBSTITUTION: User has no treadmill. Replace every running exercise " \
        "(Compromised Run, Run, Sprint, Treadmill ...) with #{pref} " \
        "(or one of: #{names.join(', ')}). Keep distance/duration unchanged."
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
      examples = filtered_examples
      json = JSON.pretty_generate(examples.map { |ex| ex.deep_stringify_keys })
      <<~EX.strip
        #{examples.size} #{@activity::NAME} workouts that show the quality bar and style. Study structure,
        exercise selection, format variety, and naming. Create something fresh in the same
        spirit — do NOT copy.

        **Variety mandate**: deliberately choose differently from the examples where you can:
        - If the examples use one cardio modality, pick a different one (run / row / ski / bike).
        - If the examples lean toward one mobility area (hip / T-spine / ankle / full-body), pick a different one.
        - Reach for less-common modalities (alternating EMOM, continuous_circuit, tabata, hundred, descending pyramid) when they fit — don't default to compromised running every session.
        - Section names must be ORIGINAL — never reuse a name from the examples. Pick fresh punchy names.

        The examples are the quality bar. Your job is to MATCH that quality while bringing something the athlete hasn't seen.

        #{json}
      EX
    end

    # Number of example workouts shown to the LLM per generation. The full
    # example pool can be large (Hyrox has 13+), but the LLM tends to pattern-
    # match whatever it sees rather than balance modalities across sessions
    # (it has no memory of prior generations, so "use modality X 1/5 of the
    # time" is meaningless single-shot). Sampling a random slice each call
    # rotates the examples the LLM sees, so output naturally varies across
    # sessions instead of fixating on the top-of-list examples.
    EXAMPLE_SAMPLE_SIZE = 4

    # Pick the example pool: intensity-filter first (strict — drop unflagged
    # "flexible" examples when intensity is set, to avoid biasing low/high
    # sessions back toward medium patterns; fall back to all examples if
    # nothing matches), then randomly sample up to EXAMPLE_SAMPLE_SIZE from
    # the result. Pools at or below the sample size are returned as-is.
    def filtered_examples
      pool = intensity_filtered_pool
      return pool if pool.size <= EXAMPLE_SAMPLE_SIZE

      pool.sample(EXAMPLE_SAMPLE_SIZE)
    end

    def intensity_filtered_pool
      return @activity::EXAMPLES unless @intensity_style.present?

      matched = @activity::EXAMPLES.select do |ex|
        ex[:intensity_style].to_s == @intensity_style.to_s
      end

      matched.presence || @activity::EXAMPLES
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

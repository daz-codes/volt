module LLMContext
  module Activities
    class UnknownActivity < StandardError; end

    # Display slug → canonical slug. Mirrors the direction of
    # WorkoutLLMGenerator::ACTIVITY_ALIASES (app/services/workout_llm_generator.rb:207–242).
    # Port every entry verbatim so the registry is a drop-in replacement in Phase 4.
    ALIASES = {
      "hybrid-training"     => "alternator",
      "cardio-strength"     => "alternator",
      "cardio-and-strength" => "alternator",
      "barry-s"             => "alternator",   # T&S now routes to alternator (spec §5)
      "barry-s-bootcamp"    => "alternator",
      "barrys"              => "alternator",
      "tread-shred"         => "alternator",
      "pump-grind"          => "alternator",   # new display name "Pump & Grind"
      "functional-fitness"  => "functional-muscle",  # Circuit Breaker absorbed into FM
      "f45"                 => "functional-muscle",
      "functional-workout"  => "functional-muscle",
      "circuit-breaker"     => "functional-muscle",  # legacy slug routes to FM now
      "hiit"                => "dynamo",
      "meta-fit"            => "dynamo",
      "metafit"             => "dynamo",
      "mega-fit"            => "dynamo",       # new display name
      "strength"            => "transformer",
      "strength-training"   => "transformer",
      "volt-strong"         => "transformer",  # new display name
      "pilates"             => "ohm",
      "yoga"                => "ohm",
      "mobility"            => "ohm",
      "volt-flow"           => "ohm",          # new display name
      "iron-engine"         => "kettlebell",
      "kettlebell-hell"     => "kettlebell",   # new display name
      "sunday-workout"      => "functional-muscle",
      "maximum-voltage"     => "functional-muscle",
      "cardio"              => "turbine",
      "pure-cardio"         => "turbine",
      "cardio-session"      => "turbine",
      "cardio-only"         => "turbine",
      "engine-room"         => "turbine",      # new display name
      "full-body-training"  => "general-fitness",
      "strong-stations"     => "deka-atlas"
    }.freeze

    # Canonical slug (as stored in the DB and seen in @activity_slug at runtime)
    # → module constant under LLMContext::Activities.
    MODULES = {
      "kettlebell"        => :IronEngine,
      "turbine"           => :Turbine,
      "alternator"        => :Alternator,
      "dynamo"            => :Dynamo,
      "transformer"       => :Transformer,
      "ohm"               => :Ohm,
      "hyrox"             => :Hyrox,
      "deka"              => :Deka,
      "deka-fit"          => :DekaFit,
      "deka-strong"       => :DekaStrong,
      "deka-mile"         => :DekaMile,
      "deka-atlas"        => :DekaAtlas,
      "functional-muscle" => :FunctionalMuscle,
      "crossfit"          => :CrossFit,
      "general-fitness"   => :GeneralFitness,
      "hybrid-race"       => :HybridRace
    }.freeze

    # One-hop resolution on purpose — see the "one-hop" test for the rationale.
    def self.canonical_slug(slug)
      s = slug.to_s
      ALIASES.fetch(s, s)
    end

    def self.for(slug)
      constant = MODULES[canonical_slug(slug)]
      return nil unless constant
      return nil unless const_defined?(constant)
      const_get(constant)
    end

    # Always returns a module. Unknown slugs fall back to GeneralFitness so
    # free-form activity names (typed in the generate form) still produce a
    # workout — the user's typed name flows through to the prompt as session
    # intent, and the LLM shapes the session from the typed name + the
    # permissive GeneralFitness contract.
    def self.for!(slug)
      self.for(slug) || GeneralFitness
    end
  end
end

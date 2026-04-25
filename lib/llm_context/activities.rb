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
      "functional-fitness"  => "circuit-breaker",
      "f45"                 => "circuit-breaker",
      "functional-workout"  => "circuit-breaker",
      "hiit"                => "dynamo",
      "meta-fit"            => "dynamo",
      "metafit"             => "dynamo",
      "strength"            => "transformer",
      "strength-training"   => "transformer",
      "pilates"             => "ohm",
      "yoga"                => "ohm",
      "mobility"            => "ohm",
      "iron-engine"         => "kettlebell",
      "sunday-workout"      => "functional-muscle",
      "maximum-voltage"     => "functional-muscle",
      "cardio"              => "turbine",
      "pure-cardio"         => "turbine",
      "cardio-session"      => "turbine",
      "cardio-only"         => "turbine",
      "full-body-training"  => "general-fitness",
      "strong-stations"     => "deka-atlas"
    }.freeze

    # Canonical slug (as stored in the DB and seen in @activity_slug at runtime)
    # → module constant under LLMContext::Activities.
    MODULES = {
      "kettlebell"        => :IronEngine,
      "turbine"           => :Turbine,
      "alternator"        => :Alternator,
      "circuit-breaker"   => :CircuitBreaker,
      "dynamo"            => :Dynamo,
      "transformer"       => :Transformer,
      "ohm"               => :Ohm,
      "hyrox"             => :Hyrox,
      "deka"              => :Deka,
      "deka-fit"          => :DekaFit,
      "deka-strong"       => :DekaStrong,
      "deka-mile"         => :DekaMile,
      "deka-atlas"        => :DekaAtlas,
      "volt-octathlon"    => :VoltOctathlon,
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

    def self.for!(slug)
      self.for(slug) || raise(UnknownActivity, "no activity module for slug #{slug.inspect}")
    end
  end
end

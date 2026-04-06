module FitnessTests
  # unit: "time" (stored as seconds), "m" (metres), "kg", "reps", "cal", "rounds"
  # scoring: :lower (time — faster is better), :higher (everything else)

  CATEGORIES = [
    {
      key: "octathlon",
      name: "Volt Octathlon",
      tests: [
        { key: "octathlon_total",    name: "Volt Octathlon (total)", unit: "time", scoring: :lower, hint: "All 8 stations back-to-back — your overall benchmark", benchmark: true, match_terms: [ "octathlon", "total" ] },
        { key: "octathlon_initi8",   name: "Initi8 — Thrusters (50 reps, 2x10kg DB)", unit: "time", scoring: :lower, hint: "Station 1", benchmark: true, match_terms: [ "initi8", "thruster" ] },
        { key: "octathlon_elev8",    name: "Elev8 — Row (1000m)",   unit: "time", scoring: :lower, hint: "Station 2", benchmark: true, match_terms: [ "elev8", "row" ] },
        { key: "octathlon_stimul8",  name: "Stimul8 — Slams (50 reps, 10kg)", unit: "time", scoring: :lower, hint: "Station 3", benchmark: true, match_terms: [ "stimul8", "slam" ] },
        { key: "octathlon_acceler8", name: "Acceler8 — Ski (1000m)", unit: "time", scoring: :lower, hint: "Station 4", benchmark: true, match_terms: [ "acceler8", "ski" ] },
        { key: "octathlon_gravit8",  name: "Gravit8 — KB Swing (50 reps, 20kg)", unit: "time", scoring: :lower, hint: "Station 5", benchmark: true, match_terms: [ "gravit8", "swing" ] },
        { key: "octathlon_domin8",   name: "Domin8 — Assault Bike (50 cal)", unit: "time", scoring: :lower, hint: "Station 6", benchmark: true, match_terms: [ "domin8", "bike" ] },
        { key: "octathlon_anihil8",  name: "Anihil8 — Devil Press (50 reps, 2x10kg DB)", unit: "time", scoring: :lower, hint: "Station 7", benchmark: true, match_terms: [ "anihil8", "devil" ] },
        { key: "octathlon_termin8",  name: "Termin8 — Run (1000m)", unit: "time", scoring: :lower, hint: "Station 8", benchmark: true, match_terms: [ "termin8", "run" ] }
      ]
    },
  ].freeze

  ALL            = CATEGORIES.flat_map { |c| c[:tests] }.freeze
  BY_KEY         = ALL.index_by { |t| t[:key] }.freeze
  ALL_KEYS       = ALL.map { |t| t[:key] }.freeze
  BENCHMARKS     = ALL.select { |t| t[:benchmark] }.freeze
  BENCHMARK_KEYS = BENCHMARKS.map { |t| t[:key] }.freeze

  def self.find(key)
    BY_KEY[key.to_s]
  end

  def self.category_for(key)
    CATEGORIES.find { |c| c[:tests].any? { |t| t[:key] == key.to_s } }
  end
end

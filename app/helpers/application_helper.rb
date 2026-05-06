module ApplicationHelper
  # The LLM occasionally HTML-entity-encodes strings ("Run &amp; Ski"). Unescape
  # once so ERB's auto-escaper produces the correct rendering.
  def clean_llm_text(str)
    return str if str.blank?
    CGI.unescapeHTML(str.to_s)
  end

  # Returns the matching benchmark test definition if the exercise name matches
  # one of the curated benchmarks, otherwise nil.
  def benchmark_for_exercise(name)
    return nil if name.blank?
    downcased = name.to_s.downcase
    FitnessTests::ALL.find do |test|
      next unless test[:match_terms].present?
      test[:match_terms].all? { |term| downcased.include?(term.downcase) }
    end
  end
  # Renders rest_secs as "X min" when a clean minute multiple, else "Xs".
  def format_rest_secs(secs)
    s = secs.to_i
    return nil if s <= 0
    if s >= 60 && (s % 60).zero?
      "#{s / 60} min"
    else
      "#{s}s"
    end
  end

  # Total distance in metres for a single workout section.
  # Handles straight/rounds sections (sum of exercise distance_m × rounds)
  # and ladder/mountain sections (distances derived from start/end/step × num exercises).
  def section_distance_m(section)
    rounds = [ section["rounds"].to_i, 1 ].max
    if %w[ladder mountain].include?(section["format"].to_s) && section["varies"] == "distance_m"
      step = [ section["step"].to_f, 1.0 ].max
      vals = []
      if section["format"] == "ladder"
        sv = section["start"].to_f; ev = section["end"].to_f
        if sv <= ev
          v = sv; while v <= ev + 0.001; vals << v; v += step; end
        else
          v = sv; while v >= ev - 0.001; vals << v; v -= step; end
        end
      else # mountain
        sv = section["start"].to_f; pk = section["peak"].to_f; ev = section["end"].to_f
        v = sv; while v <= pk + 0.001; vals << v; v += step; end
        v = pk - step; while v >= ev - 0.001; vals << v; v -= step; end
      end
      n = [ Array(section["exercises"]).length, 1 ].max
      vals.sum.to_i * n
    else
      Array(section["exercises"]).sum { |e| e["distance_m"].to_i } * rounds
    end
  end
end

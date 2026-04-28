module Workout::StructureBuilder
  extend ActiveSupport::Concern

  class_methods do
    def structure_from_params(sections_param)
      return { "sections" => [] } unless sections_param.present?

      sections = sections_param.to_unsafe_h
                               .sort_by { |k, _| k.to_i }
                               .map { |_, s| build_section_from_params(s) }
                               .reject { |s| s["name"].blank? }

      { "sections" => sections }
    end

    private

    def build_section_from_params(s)
      raw_format = s[:format].to_s
      # `continuous_circuit` is a synthetic dropdown option that maps to a
      # rotating EMOM (one exercise per minute, cycling through). Keep the
      # underlying schema clean by translating to the canonical format here.
      if raw_format == "continuous_circuit"
        format     = "emom"
        emom_style = "rotating"
      else
        format     = valid_formats.include?(raw_format) ? raw_format : "straight"
        emom_style = s[:emom_style].to_s.presence
      end

      section = {
        "name"     => s[:name].to_s.strip,
        "category" => Workout::CATEGORIES.include?(s[:category]) ? s[:category] : "main",
        "format"   => format
      }
      section["emom_style"]    = emom_style              if format == "emom" && %w[circuit rotating].include?(emom_style)
      section["intensity_style"] = s[:intensity_style].to_s if %w[zone_2 conditioning max_effort].include?(s[:intensity_style].to_s)
      section["rounds"]        = s[:rounds].to_i         if s[:rounds].present?
      section["duration_mins"] = s[:duration_mins].to_i  if s[:duration_mins].present?
      section["rest_secs"]     = s[:rest_secs].to_i      if s[:rest_secs].present?
      section["notes"]         = s[:notes].to_s.strip    if s[:notes].present?

      if %w[ladder mountain].include?(format)
        section["varies"] = s[:varies].to_s if s[:varies].present?
        %w[start end step].each do |key|
          next unless s[key.to_sym].present?
          val = s[key.to_sym].to_f
          section[key] = val == val.to_i ? val.to_i : val
        end
        if format == "mountain" && s[:peak].present?
          val = s[:peak].to_f
          section["peak"] = val == val.to_i ? val.to_i : val
        end
        section["rest_between_rungs"] = s[:rest_between_rungs].to_i if s[:rest_between_rungs].present?
      end

      if format == "switchback"
        %w[start end step].each do |key|
          next unless s[key.to_sym].present?
          val = s[key.to_sym].to_f
          section[key] = val == val.to_i ? val.to_i : val
        end
      end

      if s[:exercises].present?
        section["exercises"] = s[:exercises].sort_by { |k, _| k.to_i }
                                            .map { |_, e| build_exercise_from_params(e) }
                                            .reject { |e| e["name"].blank? }
      end

      section
    end

    def build_exercise_from_params(e)
      ex = { "name" => e[:name].to_s.strip }
      ex["notes"]      = e[:notes].to_s.strip if e[:notes].present?
      ex["reps"]       = e[:reps].to_i        if e[:reps].present?
      ex["calories"]   = e[:calories].to_i    if e[:calories].present?
      ex["distance_m"] = e[:distance_m].to_i  if e[:distance_m].present?
      if e[:duration_m].present? || e[:duration_s_part].present?
        total_s = e[:duration_m].to_i * 60 + e[:duration_s_part].to_i
        ex["duration_s"] = total_s if total_s > 0
      end
      ex["weight_kg"]  = e[:weight_kg].to_f   if e[:weight_kg].present?
      ex
    end
  end
end

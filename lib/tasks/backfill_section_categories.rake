namespace :workouts do
  desc "Backfill section categories on existing workouts"
  task backfill_categories: :environment do
    updated = 0
    Workout.find_each do |workout|
      next unless workout.structure.is_a?(Hash)
      sections = Array(workout.structure["sections"])
      next if sections.empty?

      changed = false
      sections.each_with_index do |section, i|
        next if Workout::CATEGORIES.include?(section["category"])

        section["category"] = infer_category(section, sections, i)
        changed = true
      end

      if changed
        workout.update_column(:structure, workout.structure)
        updated += 1
      end
    end
    puts "Backfilled #{updated} workouts"
  end

  private

  def infer_category(section, all_sections, index)
    name = section["name"].to_s
    fmt = section["format"].to_s

    if name.match?(Workout::WARMUP_NAME_PATTERN)
      "warm_up"
    elsif name.match?(Workout::COOLDOWN_NAME_PATTERN)
      "cool_down"
    elsif %w[tabata hundred for_time].include?(fmt) && index == last_non_cooldown_index(all_sections)
      has_prior_main = all_sections[0...index].any? { |s|
        !s["name"].to_s.match?(Workout::WARMUP_NAME_PATTERN) &&
        !s["name"].to_s.match?(Workout::COOLDOWN_NAME_PATTERN)
      }
      has_prior_main ? "finisher" : "main"
    else
      "main"
    end
  end

  def last_non_cooldown_index(sections)
    sections.rindex { |s| !s["name"].to_s.match?(Workout::COOLDOWN_NAME_PATTERN) }
  end
end

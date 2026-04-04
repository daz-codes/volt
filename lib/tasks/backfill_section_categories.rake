namespace :workouts do
  desc "Backfill section categories on existing workouts"
  task backfill_categories: :environment do
    updated = 0
    Workout.find_each do |workout|
      next unless workout.structure.is_a?(Hash)
      sections = Array(workout.structure["sections"])
      next if sections.size < 2

      changed = false

      # First section is always warm_up
      if sections.first["category"] != "warm_up"
        sections.first["category"] = "warm_up"
        changed = true
      end

      # Last section is always cool_down
      if sections.last["category"] != "cool_down"
        sections.last["category"] = "cool_down"
        changed = true
      end

      if changed
        workout.update_column(:structure, workout.structure)
        updated += 1
      end
    end
    puts "Updated #{updated} workouts"
  end
end

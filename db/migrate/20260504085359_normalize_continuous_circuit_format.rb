class NormalizeContinuousCircuitFormat < ActiveRecord::Migration[8.2]
  # Promote continuous-circuit sections from the legacy `format=emom + emom_style=rotating`
  # encoding to the first-class `format=continuous_circuit` shape across both `structure`
  # and `original_structure` JSON columns.
  def up
    Workout.find_each do |w|
      changed = false
      changed = rewrite_sections!(w.structure) || changed
      changed = rewrite_sections!(w.original_structure) || changed
      w.save!(validate: false) if changed
    end
  end

  def down
    Workout.find_each do |w|
      changed = false
      changed = revert_sections!(w.structure) || changed
      changed = revert_sections!(w.original_structure) || changed
      w.save!(validate: false) if changed
    end
  end

  private

  def rewrite_sections!(structure)
    return false unless structure.is_a?(Hash)
    sections = Array(structure["sections"])
    changed = false
    sections.each do |s|
      next unless s.is_a?(Hash)
      next unless s["format"] == "emom" && s["emom_style"] == "rotating"
      s["format"] = "continuous_circuit"
      s.delete("emom_style")
      changed = true
    end
    changed
  end

  def revert_sections!(structure)
    return false unless structure.is_a?(Hash)
    sections = Array(structure["sections"])
    changed = false
    sections.each do |s|
      next unless s.is_a?(Hash) && s["format"] == "continuous_circuit"
      s["format"] = "emom"
      s["emom_style"] = "rotating"
      changed = true
    end
    changed
  end
end

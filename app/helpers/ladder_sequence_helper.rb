module LadderSequenceHelper
  def ladder_values_for(section, exercise)
    Workout::LadderSequence.values_for(section, exercise)
  end

  def ladder_unit_label_for(section, exercise)
    Workout::LadderSequence.unit_label_for(section, exercise)
  end

  def ladder_has_per_exercise_overrides?(section)
    Workout::LadderSequence.has_per_exercise_overrides?(section)
  end
end

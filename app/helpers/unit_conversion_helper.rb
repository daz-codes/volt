module UnitConversionHelper
  CM_PER_INCH = 2.54
  KG_PER_LB   = 0.453592

  # Converts cm (numeric) to [feet, inches] with inches rounded to nearest integer.
  # Handles inch rollover (e.g. 60in becomes 5 ft, 0 in).
  def cm_to_ft_in(cm)
    return nil if cm.nil?
    total_inches = (cm.to_f / CM_PER_INCH).round
    [ total_inches / 12, total_inches % 12 ]
  end

  # Converts feet + inches to integer cm. Nil inches treated as 0.
  def ft_in_to_cm(feet, inches)
    return nil if feet.nil?
    ((feet.to_i * 12 + inches.to_i) * CM_PER_INCH).round
  end

  # Converts kg to lbs, rounded to nearest 0.5.
  def kg_to_lbs(kg)
    return nil if kg.nil?
    lbs = kg.to_f / KG_PER_LB
    (lbs * 2).round / 2.0
  end

  # Converts lbs to kg, rounded to 1 decimal place.
  def lbs_to_kg(lbs)
    return nil if lbs.nil?
    (lbs.to_f * KG_PER_LB).round(1)
  end

  # Formats a user's height for display based on their unit_system.
  # Returns nil if no height.
  def format_height(user)
    return nil if user.height_cm.blank?
    if user.unit_system == "imperial"
      ft, inches = cm_to_ft_in(user.height_cm)
      %(#{ft}'#{inches}")
    else
      "#{user.height_cm}cm"
    end
  end

  # Formats a user's weight for display based on their unit_system.
  # Returns nil if no weight.
  def format_weight(user)
    return nil if user.weight_kg.blank?
    if user.unit_system == "imperial"
      lbs = kg_to_lbs(user.weight_kg)
      lbs == lbs.to_i ? "#{lbs.to_i}lbs" : "#{lbs}lbs"
    else
      kg = user.weight_kg.to_f
      kg == kg.to_i ? "#{kg.to_i}kg" : "#{kg.round(1)}kg"
    end
  end
end

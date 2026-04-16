require "test_helper"

class UnitConversionHelperTest < ActionView::TestCase
  include UnitConversionHelper

  # cm_to_ft_in
  test "cm_to_ft_in converts 180cm to 5ft 11in" do
    assert_equal [5, 11], cm_to_ft_in(180)
  end

  test "cm_to_ft_in converts 183cm to 6ft 0in" do
    assert_equal [6, 0], cm_to_ft_in(183)
  end

  test "cm_to_ft_in converts 152cm to 4ft 12in rounded to 5ft 0in" do
    # 152cm = 59.842in — rounds to 60in = 5ft 0in
    assert_equal [5, 0], cm_to_ft_in(152)
  end

  test "cm_to_ft_in handles nil" do
    assert_nil cm_to_ft_in(nil)
  end

  # ft_in_to_cm
  test "ft_in_to_cm converts 5ft 11in to 180cm" do
    assert_equal 180, ft_in_to_cm(5, 11)
  end

  test "ft_in_to_cm converts 6ft 0in to 183cm" do
    assert_equal 183, ft_in_to_cm(6, 0)
  end

  test "ft_in_to_cm handles nil inches as zero" do
    assert_equal 183, ft_in_to_cm(6, nil)
  end

  test "ft_in_to_cm returns nil if feet is nil" do
    assert_nil ft_in_to_cm(nil, 5)
  end

  # kg_to_lbs
  test "kg_to_lbs converts 80kg to 176.5lbs rounded to nearest 0.5" do
    # 80 * 2.20462 = 176.3696 → rounds to 176.5
    assert_equal 176.5, kg_to_lbs(80)
  end

  test "kg_to_lbs converts 75kg to nearest 0.5" do
    # 75 * 2.20462 = 165.3465 → rounds to 165.5
    assert_equal 165.5, kg_to_lbs(75)
  end

  test "kg_to_lbs handles nil" do
    assert_nil kg_to_lbs(nil)
  end

  # lbs_to_kg
  test "lbs_to_kg converts 176lbs to 79.8kg" do
    # 176 * 0.453592 = 79.832 → rounded to 1 decimal = 79.8
    assert_equal 79.8, lbs_to_kg(176)
  end

  test "lbs_to_kg handles nil" do
    assert_nil lbs_to_kg(nil)
  end

  # format_height
  test "format_height metric shows cm" do
    user = User.new(height_cm: 180, unit_system: "metric")
    assert_equal "180cm", format_height(user)
  end

  test "format_height imperial shows ft and in" do
    user = User.new(height_cm: 180, unit_system: "imperial")
    assert_equal %{5'11"}, format_height(user)
  end

  test "format_height imperial shows zero inches" do
    user = User.new(height_cm: 183, unit_system: "imperial")
    assert_equal %{6'0"}, format_height(user)
  end

  test "format_height returns nil if no height" do
    user = User.new(height_cm: nil, unit_system: "metric")
    assert_nil format_height(user)
  end

  # format_weight
  test "format_weight metric shows kg" do
    user = User.new(weight_kg: 80, unit_system: "metric")
    assert_equal "80kg", format_weight(user)
  end

  test "format_weight metric with decimal shows one decimal place" do
    user = User.new(weight_kg: 80.5, unit_system: "metric")
    assert_equal "80.5kg", format_weight(user)
  end

  test "format_weight metric handles BigDecimal from DB" do
    user = User.new(weight_kg: BigDecimal("80.5"), unit_system: "metric")
    assert_equal "80.5kg", format_weight(user)
  end

  test "format_weight imperial shows lbs" do
    user = User.new(weight_kg: 80, unit_system: "imperial")
    assert_equal "176.5lbs", format_weight(user)
  end

  test "format_weight imperial whole number drops decimal" do
    user = User.new(weight_kg: 81.647, unit_system: "imperial")
    # 81.647kg = 180.0lbs → whole number
    assert_equal "180lbs", format_weight(user)
  end

  test "format_weight returns nil if no weight" do
    user = User.new(weight_kg: nil, unit_system: "metric")
    assert_nil format_weight(user)
  end
end

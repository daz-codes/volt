require "test_helper"

class ScannableTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess

  # Minimal stub helper (minitest 6 ships without minitest/mock).
  # Temporarily overrides obj.method_name to return value for the duration of
  # the block. Works for class methods, singleton methods, and instance methods.
  def stub_method(obj, method_name, value)
    obj.define_singleton_method(method_name) { |*| value }
    yield
  ensure
    obj.singleton_class.send(:remove_method, method_name)
  end

  setup do
    @user = users(:one)
    @valid_tool_response = {
      "name" => "Whiteboard AMRAP",
      "duration_mins" => 30,
      "activity" => "CrossFit",
      "structure" => {
        "goal" => "Complete as many rounds as possible",
        "sections" => [
          {
            "name" => "AMRAP 20",
            "format" => "amrap",
            "duration_mins" => 20,
            "exercises" => [
              { "name" => "Pull-Ups", "reps" => 10 },
              { "name" => "Push-Ups", "reps" => 20 },
              { "name" => "Air Squats", "reps" => 30 }
            ]
          }
        ]
      }
    }
  end

  test "scan_from_image returns unsaved workout with structure" do
    image = fixture_file_upload("workout_screenshot.jpg", "image/jpeg")

    stub_method(Workout, :call_scan_api, @valid_tool_response) do
      workout = Workout.scan_from_image(image: image, user: @user)

      assert_not workout.persisted?
      assert_equal "Whiteboard AMRAP", workout.name
      assert_equal 30, workout.duration_mins
      assert_equal @user, workout.user
      assert workout.structure.present?
    end
  end

  test "scan_from_image defaults duration_mins when missing" do
    response = @valid_tool_response.merge("duration_mins" => 0)
    image = fixture_file_upload("workout_screenshot.jpg", "image/jpeg")

    stub_method(Workout, :call_scan_api, response) do
      workout = Workout.scan_from_image(image: image, user: @user)
      assert_equal 45, workout.duration_mins
    end
  end

  test "scan_from_image looks up activity from response" do
    image = fixture_file_upload("workout_screenshot.jpg", "image/jpeg")

    stub_method(Workout, :call_scan_api, @valid_tool_response) do
      workout = Workout.scan_from_image(image: image, user: @user)
      assert_equal "CrossFit", workout.activity&.name
    end
  end

  test "scan_from_image rejects files over 5MB" do
    image = fixture_file_upload("workout_screenshot.jpg", "image/jpeg")

    stub_method(image, :size, 6.megabytes) do
      assert_raises(Scannable::ScanError) do
        Workout.scan_from_image(image: image, user: @user)
      end
    end
  end

  test "scan_from_image rejects non-image content types" do
    image = fixture_file_upload("workout_screenshot.jpg", "text/plain")

    assert_raises(Scannable::ScanError) do
      Workout.scan_from_image(image: image, user: @user)
    end
  end

  test "scan_from_image raises ScanError on empty structure" do
    empty_response = @valid_tool_response.merge(
      "structure" => { "sections" => [] }
    )
    image = fixture_file_upload("workout_screenshot.jpg", "image/jpeg")

    stub_method(Workout, :call_scan_api, empty_response) do
      assert_raises(Scannable::ScanError) do
        Workout.scan_from_image(image: image, user: @user)
      end
    end
  end
end

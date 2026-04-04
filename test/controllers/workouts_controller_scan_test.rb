require "test_helper"

class WorkoutsControllerScanTest < ActionDispatch::IntegrationTest
  # Temporarily overrides a class/singleton method for the duration of a block.
  # Minitest 6 ships without minitest/mock stub support for arbitrary objects.
  # If value is a Proc/lambda it is called with the original arguments.
  def stub_method(obj, method_name, value)
    if value.respond_to?(:call)
      obj.define_singleton_method(method_name) { |*args| value.call(*args) }
    else
      obj.define_singleton_method(method_name) { |*| value }
    end
    yield
  ensure
    obj.singleton_class.send(:remove_method, method_name)
  end

  setup do
    @user = users(:one)
    sign_in_as @user
    @image = fixture_file_upload("workout_screenshot.jpg", "image/jpeg")
    @valid_response = {
      "name" => "Scanned AMRAP",
      "duration_mins" => 30,
      "activity" => "CrossFit",
      "structure" => {
        "sections" => [
          { "name" => "AMRAP", "format" => "amrap", "duration_mins" => 20,
            "exercises" => [ { "name" => "Burpees", "reps" => 10 } ] }
        ]
      }
    }
  end

  test "scan redirects to preview on success" do
    stub_method(Workout, :call_scan_api, @valid_response) do
      post scan_workouts_path, params: { image: @image }
    end
    assert_response :redirect
    assert_match %r{workouts/preview/}, response.location
  end

  test "scan creates generation_uses record" do
    stub_method(Workout, :call_scan_api, @valid_response) do
      assert_difference "@user.generation_uses.count", 1 do
        post scan_workouts_path, params: { image: @image }
      end
    end
  end

  test "scan redirects with error when generation limit reached" do
    User::FREE_GENERATION_LIMIT.times { @user.generation_uses.create! }

    post scan_workouts_path, params: { image: @image }
    assert_redirected_to root_path
    assert_match(/generations this week/, flash[:alert])
  end

  test "scan redirects with error on invalid image type" do
    bad_image = fixture_file_upload("workout_screenshot.jpg", "text/plain")

    post scan_workouts_path, params: { image: bad_image }
    assert_redirected_to root_path
    assert_match(/JPEG, PNG, GIF, or WebP/, flash[:alert])
  end

  test "scan redirects with error when no image provided" do
    post scan_workouts_path
    assert_redirected_to root_path
    assert_match(/upload an image/, flash[:alert])
  end

  test "scan redirects with error on API failure" do
    stub_method(Workout, :call_scan_api, ->(*) { raise Scannable::ScanError, "AI is overloaded" }) do
      post scan_workouts_path, params: { image: @image }
    end
    assert_redirected_to root_path
    assert_match(/overloaded/, flash[:alert])
  end

  test "scan requires authentication" do
    sign_out
    post scan_workouts_path, params: { image: @image }
    assert_response :redirect
  end
end

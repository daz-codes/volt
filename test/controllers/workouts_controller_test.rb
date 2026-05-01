require "test_helper"
require "ostruct"

class WorkoutsControllerTest < ActionDispatch::IntegrationTest
  # Temporarily replaces WorkoutLLMGenerator.new with a kwarg-capturing stub.
  # Yields the captured kwargs hash (mutated by the stub) so the test body
  # can assert on it after the request runs.
  def with_generator_stub
    captured = {}
    fake_result = { attrs: {}, debug_info: [], group_tag_name: nil }
    fake_instance = OpenStruct.new(generate: fake_result)

    WorkoutLLMGenerator.singleton_class.alias_method(:__orig_new, :new)
    WorkoutLLMGenerator.define_singleton_method(:new) do |**kwargs|
      captured.merge!(kwargs)
      fake_instance
    end

    yield captured
  ensure
    WorkoutLLMGenerator.singleton_class.send(:alias_method, :new, :__orig_new)
    WorkoutLLMGenerator.singleton_class.send(:remove_method, :__orig_new)
  end

  setup do
    @user = users(:one)
    sign_in_as(@user)
    @workout = workouts(:hyrox_session)
  end

  test "library requires authentication" do
    sign_out
    get library_path
    assert_response :redirect
  end

  test "library renders" do
    get library_path
    assert_response :success
  end

  test "library excludes workouts that belong to a program" do
    get library_path
    assert_response :success
    assert_no_match workouts(:hyrox_session).name, response.body
  end

  test "library filters by activity" do
    get library_path, params: { activity: "Hyrox" }
    assert_response :success
  end

  test "show renders workout" do
    get workout_path(@workout)
    assert_response :success
  end

  test "show renders for non-owner" do
    sign_out
    sign_in_as(users(:two))
    get workout_path(@workout)
    assert_response :success
  end

  test "clone creates a copy" do
    assert_difference "Workout.count", 1 do
      post clone_workout_path(@workout)
    end
    assert_redirected_to edit_workout_path(Workout.last)
  end

  test "clone copies activity" do
    post clone_workout_path(@workout)
    cloned = Workout.last
    assert_equal @workout.activity_id, cloned.activity_id
  end

  test "destroy removes owned workout" do
    standalone = workouts(:strength_session)
    assert_difference "Workout.count", -1 do
      delete workout_path(standalone)
    end
  end

  test "create_with_llm forwards intensity_style to generator when valid" do
    with_generator_stub do |captured|
      post workouts_path, params: { activity: "Functional Muscle", duration_mins: 45, intensity_style: "zone_2" }
      assert_equal "zone_2", captured[:intensity_style]
    end
  end

  test "create_with_llm passes nil when intensity_style is blank" do
    with_generator_stub do |captured|
      post workouts_path, params: { activity: "Functional Muscle", duration_mins: 45, intensity_style: "" }
      assert_nil captured[:intensity_style]
    end
  end

  test "create_with_llm rejects unknown intensity_style values" do
    with_generator_stub do |captured|
      post workouts_path, params: { activity: "Functional Muscle", duration_mins: 45, intensity_style: "garbage" }
      assert_nil captured[:intensity_style]
    end
  end
end

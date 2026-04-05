require "test_helper"

class User::HasDefaultDifficultyTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    # Clear any existing logs to start fresh
    @user.workout_logs.destroy_all
  end

  test "returns 3 when user has no posting history" do
    assert_equal 3, @user.default_difficulty_level
  end

  test "returns the weighted average of recent difficulty levels" do
    workout = workouts(:hyrox_session)
    5.times do |i|
      @user.workout_logs.create!(
        workout: workout,
        completed_at: (5 - i).days.ago,
        sweat_rating: 3,
        difficulty_level: 4
      )
    end

    assert_equal 4, @user.default_difficulty_level
  end

  test "weights recent posts more heavily" do
    workout = workouts(:hyrox_session)
    # 10 old posts at level 2
    10.times do |i|
      @user.workout_logs.create!(
        workout: workout,
        completed_at: (20 - i).days.ago,
        sweat_rating: 3,
        difficulty_level: 2
      )
    end
    # 3 recent posts at level 5
    3.times do |i|
      @user.workout_logs.create!(
        workout: workout,
        completed_at: (3 - i).days.ago,
        sweat_rating: 3,
        difficulty_level: 5
      )
    end

    # Recent level-5 posts should pull the average above 3
    result = @user.default_difficulty_level
    assert result >= 3, "Expected >= 3 due to recency weighting, got #{result}"
  end

  test "clamps result to 1-5 range" do
    workout = workouts(:hyrox_session)
    @user.workout_logs.create!(
      workout: workout,
      completed_at: 1.day.ago,
      sweat_rating: 3,
      difficulty_level: 5
    )

    result = @user.default_difficulty_level
    assert_includes 1..5, result
  end
end

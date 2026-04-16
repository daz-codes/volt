class ProfilesController < ApplicationController
  before_action :require_authentication

  def show
    @user = Current.user
    @workout_count = @user.workout_logs.count
    @follower_count = @user.followers.count
    @following_count = @user.following.count
    entries = Current.user.fitness_test_entries.where(test_key: FitnessTests::BENCHMARK_KEYS)
    @best_by_key = FitnessTests::BENCHMARKS.each_with_object({}) do |test, h|
      relevant = entries.select { |e| e.test_key == test[:key] }
      h[test[:key]] = test[:scoring] == :lower ? relevant.min_by(&:value) : relevant.max_by(&:value)
    end
  end

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user
    @user.assign_attributes(profile_params)
    @user.equipment = Array(params.dig(:user, :equipment))
                        .compact_blank
                        .intersection(User::EQUIPMENT_SLUGS)

    if @user.save
      redirect_to profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.expect(user: [ :username, :display_name, :avatar,
      :age, :height_cm, :weight_kg, :gender,
      :pool_length, :speed_unit, :unit_system, :injury_notes ])
  end
end

module User::HasDefaultDifficulty
  extend ActiveSupport::Concern

  DEFAULT_DIFFICULTY = 3
  HISTORY_LIMIT = 20
  DECAY_FACTOR = 0.85 # Each older post is worth 85% of the one before it

  def default_difficulty_level
    levels = workout_logs
      .where.not(difficulty_level: nil)
      .order(completed_at: :desc)
      .limit(HISTORY_LIMIT)
      .pluck(:difficulty_level)

    return DEFAULT_DIFFICULTY if levels.empty?

    weighted_sum = 0.0
    weight_total = 0.0

    levels.each_with_index do |level, i|
      weight = DECAY_FACTOR**i
      weighted_sum += level * weight
      weight_total += weight
    end

    (weighted_sum / weight_total).round.clamp(1, 5)
  end
end

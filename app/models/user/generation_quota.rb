module User::GenerationQuota
  extend ActiveSupport::Concern

  included do
    has_many :generation_uses, dependent: :destroy
  end

  def generations_this_week
    generation_uses.where(created_at: 1.week.ago..).count
  end

  def generation_limit
    if pro?
      nil
    elsif beta?
      self.class::BETA_GENERATION_LIMIT
    else
      self.class::FREE_GENERATION_LIMIT
    end
  end

  def generation_limit_reached?
    return false if pro?
    generations_this_week >= generation_limit
  end

  def generations_remaining
    return nil if pro?
    [ generation_limit - generations_this_week, 0 ].max
  end
end

class Activity < ApplicationRecord
  DEFAULT_NAMES = [
    "Alternator", "Tread & Shred", "Circuit Breaker", "Dynamo",
    "Transformer", "Ohm", "CrossFit", "Kettlebell",
    "Functional Muscle", "Hyrox", "Deka", "Deka Strong", "Deka Atlas"
  ].freeze

  has_many :workouts
  has_many :programs

  validates :name, presence: true, uniqueness: true

  scope :defaults, -> { where(name: DEFAULT_NAMES) }

  def slug
    name.parameterize
  end
end

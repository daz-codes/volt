class Activity < ApplicationRecord
  DEFAULT_NAMES = [
    "Functional Muscle", "Volt Strong", "Pump & Grind", "Mega Fit",
    "Kettlebell Hell", "Volt Flow", "Engine Room",
    "Hybrid Race", "Strong Stations",
    "CrossFit", "Kettlebell", "Sunday Workout",
    "Hyrox", "Deka", "Deka Strong", "Deka Atlas"
  ].freeze

  has_many :workouts
  has_many :programs

  validates :name, presence: true, uniqueness: true

  scope :defaults, -> { where(name: DEFAULT_NAMES) }

  def slug
    name.parameterize
  end
end

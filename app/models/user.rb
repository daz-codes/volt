class User < ApplicationRecord
  FREE_GENERATION_LIMIT = 5
  BETA_GENERATION_LIMIT = 25

  # Equipment the user has access to. Used to filter workout generation so the
  # LLM doesn't suggest exercises they can't perform. Stored as an array of
  # slugs in the `equipment` JSON column.
  #
  # Semantics:
  #   nil / []                        → no constraint (treat as "has everything")
  #   array containing all slugs      → no constraint (same as above)
  #   partial array                   → constraint — only suggest these items
  EQUIPMENT_OPTIONS = {
    "barbell"          => "Barbell",
    "dumbbells"        => "Dumbbells",
    "kettlebells"      => "Kettlebells",
    "pull_up_bar"      => "Pull-up Bar",
    "wall_ball"        => "Wall Ball",
    "sled"             => "Sled",
    "resistance_bands" => "Resistance Bands",
    "jump_rope"        => "Jump Rope",
    "rowing_machine"   => "Rowing Machine",
    "assault_bike"     => "Assault Bike",
    "ski_erg"          => "Ski Erg",
    "treadmill"        => "Treadmill"
  }.freeze

  EQUIPMENT_SLUGS = EQUIPMENT_OPTIONS.keys.freeze

  # Returns the user's equipment list with defaults applied — blank means
  # "has everything", so return all slugs. Used by the profile edit form and
  # the generate session form to pre-check boxes.
  def equipment_with_defaults
    list = Array(equipment).compact_blank
    list.empty? ? EQUIPMENT_SLUGS : list
  end

  include User::Billing
  include User::GenerationQuota
  include User::FollowGraph
  include User::FitnessTracking
  include User::ExerciseWeightRecorder
  include User::HasDefaultDifficulty

  validates :email_address, uniqueness: true
  validates :username, uniqueness: true, allow_nil: true,
            format: { with: /\A[a-zA-Z0-9_]{3,30}\z/,
                      message: "must be 3–30 characters: letters, numbers, and underscores only" }
  has_secure_password validations: false
  validates :password, presence: true, length: { minimum: 8 }, unless: :skip_password_validation?
  validates :password, length: { minimum: 8 }, allow_nil: true, if: :skip_password_validation?

  attr_accessor :skip_password_validation
  has_many :identities, dependent: :destroy
  has_many :sessions, dependent: :delete_all
  has_many :comments, dependent: :destroy
  has_many :workouts, dependent: :destroy
  has_many :workout_logs, dependent: :destroy
  has_many :programs, dependent: :destroy
  has_many :challenge_entries, dependent: :destroy
  has_many :notifications, foreign_key: :recipient_id, dependent: :delete_all

  has_many :shares_sent,     class_name: "Share", foreign_key: :sender_id,    dependent: :destroy
  has_many :shares_received, class_name: "Share", foreign_key: :recipient_id, dependent: :destroy

  has_one_attached :avatar

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :username, with: ->(u) { u.presence }  # treat blank as nil

  def unread_notification_count
    notifications.unread.count
  end

  def display
    display_name.presence || username.presence || email_address.split("@").first
  end

  def initials
    display.first(1).upcase
  end

  def oauth_user?
    identities.exists?
  end

  private

  def skip_password_validation?
    skip_password_validation || (persisted? && !password_changed?)
  end

  def password_changed?
    password.present?
  end
end

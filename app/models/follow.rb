class Follow < ApplicationRecord
  include Notifiable

  belongs_to :follower,  class_name: "User"
  belongs_to :following, class_name: "User"

  validates :follower_id, uniqueness: { scope: :following_id }
  validate  :cannot_follow_self

  before_create do
    self.status       = "accepted"
    self.requested_at = Time.current
    self.accepted_at  = Time.current
  end

  notifies action: :new_follower, recipient: :following, actor: :follower

  scope :accepted, -> { where(status: "accepted") }

  private

  def cannot_follow_self
    errors.add(:follower_id, "can't follow yourself") if follower_id == following_id
  end
end

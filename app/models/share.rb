class Share < ApplicationRecord
  belongs_to :sender,    class_name: "User"
  belongs_to :recipient, class_name: "User"
  belongs_to :shareable, polymorphic: true

  validates :recipient_id, uniqueness: { scope: [ :sender_id, :shareable_type, :shareable_id ],
                                         message: "already has this shared with them" }
  validate :cannot_share_to_self

  after_create_commit :notify_recipient

  private

  def cannot_share_to_self
    errors.add(:recipient_id, "can't share with yourself") if sender_id == recipient_id
  end

  def notify_recipient
    Notification.create!(
      recipient:  recipient,
      actor:      sender,
      notifiable: self,
      action:     "share"
    )
  end
end

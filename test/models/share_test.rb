require "test_helper"

class ShareTest < ActiveSupport::TestCase
  test "cannot share to yourself" do
    share = Share.new(sender: users(:one), recipient: users(:one), shareable: workouts(:hyrox_session))
    assert_not share.valid?
    assert share.errors[:recipient_id].any?
  end

  test "creates notification on share" do
    assert_difference "Notification.count", 1 do
      Share.create!(sender: users(:one), recipient: users(:two), shareable: workouts(:hyrox_session))
    end
    notification = Notification.last
    assert_equal "share", notification.action
    assert_equal users(:two), notification.recipient
    assert_equal users(:one), notification.actor
  end

  test "prevents duplicate shares" do
    Share.create!(sender: users(:one), recipient: users(:two), shareable: workouts(:hyrox_session))
    duplicate = Share.new(sender: users(:one), recipient: users(:two), shareable: workouts(:hyrox_session))
    assert_not duplicate.valid?
  end
end

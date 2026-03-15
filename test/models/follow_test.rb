require "test_helper"

class FollowTest < ActiveSupport::TestCase
  test "cannot follow yourself" do
    follow = Follow.new(follower: users(:one), following: users(:one))
    assert_not follow.valid?
  end

  test "auto-accepts on create" do
    follow = Follow.create!(follower: users(:two), following: users(:one))
    assert_equal "accepted", follow.status
    assert_not_nil follow.accepted_at
  end

  test "accepted scope" do
    assert_includes Follow.accepted, follows(:one_follows_two)
  end

  test "validates uniqueness of follower per following" do
    duplicate = Follow.new(
      follower: follows(:one_follows_two).follower,
      following: follows(:one_follows_two).following
    )
    assert_not duplicate.valid?
  end
end

module User::FollowGraph
  extend ActiveSupport::Concern

  included do
    has_many :follows_as_follower,  class_name: "Follow", foreign_key: :follower_id,  dependent: :destroy
    has_many :follows_as_following, class_name: "Follow", foreign_key: :following_id, dependent: :destroy

    has_many :following, through: :follows_as_follower, source: :following
    has_many :followers, through: :follows_as_following, source: :follower
  end

  # IDs of users this user is accepted-following (for feed query)
  def accepted_following_ids
    follows_as_follower.accepted.pluck(:following_id)
  end

  # Follow state this user has toward another user
  def follow_state_for(other_user)
    return :self if id == other_user.id
    follow = follows_as_follower.find_by(following_id: other_user.id)
    return follow.status.to_sym if follow

    # Not following them — do they follow us?
    follows_as_following.exists?(follower_id: other_user.id) ? :follow_back : :none
  end
end

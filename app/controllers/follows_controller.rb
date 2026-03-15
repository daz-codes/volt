class FollowsController < ApplicationController
  before_action :require_authentication
  before_action :set_follow, only: :destroy

  # POST /follows
  def create
    target = User.find(params[:following_id])

    if target == Current.user
      head :unprocessable_entity and return
    end

    follow = Current.user.follows_as_follower.find_or_create_by!(following: target)

    @follow_state = follow.status.to_sym
    @target_user  = target

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: user_path(target) }
    end
  end

  # DELETE /follows/:id — unfollow
  def destroy
    target = @follow.following == Current.user ? @follow.follower : @follow.following
    @follow.destroy!
    @follow_state = Current.user.follow_state_for(target)
    @target_user  = target

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: user_path(target) }
    end
  end

  private

  def set_follow
    @follow = Follow.find(params[:id])
    unless @follow.follower == Current.user || @follow.following == Current.user
      head :forbidden
    end
  end
end

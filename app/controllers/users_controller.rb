class UsersController < ApplicationController
  before_action :require_authentication

  # GET /users?q=
  def index
    if params[:q].present?
      q = "%#{params[:q].gsub('%', '').gsub('_', '\\_')}%"
      @users = User.where("username LIKE :q OR display_name LIKE :q OR email_address LIKE :q", q: q)
                   .where.not(id: Current.user.id)
                   .limit(20)
    else
      @users = []
    end
  end

  # POST /users/contacts_search — called by the Contact Picker Stimulus controller.
  # Receives an array of emails from the device contacts, returns matched users
  # and a list of unmatched emails so the UI can offer invites.
  def contacts_search
    emails = Array(params[:emails]).map { |e| e.strip.downcase }.uniq.first(200)
    @matched   = User.where(email_address: emails).where.not(id: Current.user.id).limit(50)
    matched_emails = @matched.pluck(:email_address)
    @unmatched_count = (emails - matched_emails - [ Current.user.email_address ]).size
  end

  # GET /users/:id
  def show
    @profile_user = User.find(params[:id])

    # Redirect to own edit profile if viewing self
    if @profile_user == Current.user
      redirect_to edit_profile_path and return
    end

    @follow_state   = Current.user.follow_state_for(@profile_user)
    @follow         = Current.user.follows_as_follower.find_by(following: @profile_user)
    @workout_count  = @profile_user.workout_logs.count
    @follower_count = @profile_user.follows_as_following.accepted.count
    @following_count = @profile_user.follows_as_follower.accepted.count

    @page = [ params[:page].to_i, 1 ].max
    per_page = 10
    offset = (@page - 1) * per_page

    results = @profile_user.workout_logs
                           .includes(:user, :tags, photo_attachment: :blob, workout: [ :tags, :activity, :workout_likes ])
                           .recent
                           .offset(offset)
                           .limit(per_page + 1)
                           .to_a

    @has_more     = results.size > per_page
    @workout_logs = results.first(per_page)
    @next_page    = @page + 1
    workout_ids   = @workout_logs.map(&:workout_id)
    @liked_workout_ids = workout_ids.any? ? WorkoutLike.where(user_id: Current.user.id, workout_id: workout_ids).pluck(:workout_id).to_set : Set.new
    owned_ids = Current.user.workouts.where(id: workout_ids).pluck(:id)
    saved_source_ids = Current.user.workouts.where(source_workout_id: workout_ids).pluck(:source_workout_id)
    @library_workout_ids = (owned_ids + saved_source_ids).to_set
  end
end

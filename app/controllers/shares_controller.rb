class SharesController < ApplicationController
  before_action :require_authentication

  # POST /shares
  def create
    shareable = find_shareable
    recipient = User.find(params[:recipient_id])

    share = Share.new(
      sender:    Current.user,
      recipient: recipient,
      shareable: shareable,
      message:   params[:message].presence
    )

    if share.save
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(
          "share_dialog_status",
          html: "<p id='share_dialog_status' class='text-lime-400 text-sm font-semibold mt-3'>Sent to #{recipient.display}!</p>".html_safe
        ) }
        format.html { redirect_back fallback_location: root_path, notice: "Shared with #{recipient.display}." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(
          "share_dialog_status",
          html: "<p id='share_dialog_status' class='text-red-400 text-sm font-semibold mt-3'>#{share.errors.full_messages.first}</p>".html_safe
        ) }
        format.html { redirect_back fallback_location: root_path, alert: share.errors.full_messages.first }
      end
    end
  end

  # GET /shares/search_users?q=...
  def search_users
    if params[:q].present? && params[:q].length >= 2
      q = "%#{params[:q].gsub('%', '').gsub('_', '\\_')}%"
      @users = User.where("username LIKE :q OR display_name LIKE :q OR email_address LIKE :q", q: q)
                   .where.not(id: Current.user.id)
                   .limit(10)
    else
      @users = []
    end

    render layout: false
  end

  private

  def find_shareable
    case params[:shareable_type]
    when "Workout"
      Workout.find(params[:shareable_id])
    when "Program"
      Program.find(params[:shareable_id])
    else
      raise ActiveRecord::RecordNotFound
    end
  end
end

module NotificationsHelper
  def notification_path_for(notification)
    case notification.action
    when "new_follower"
      user_path(notification.actor)
    when "comment"
      workout_log_path(notification.notifiable.workout_log)
    when "like"
      workout_path(notification.notifiable.workout)
    when "share"
      share = notification.notifiable
      share.shareable_type == "Workout" ? workout_path(share.shareable) : program_path(share.shareable)
    else
      notifications_path
    end
  rescue
    notifications_path
  end

  def notification_icon(action)
    case action
    when "new_follower"    then "👋"
    when "comment"         then "💬"
    when "like"            then "⚡"
    when "share"           then "📤"
    end
  end
end

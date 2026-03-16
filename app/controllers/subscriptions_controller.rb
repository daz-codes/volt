class SubscriptionsController < ApplicationController
  before_action :require_authentication

  def upgrade
    Current.user.update!(plan: "pro")
    redirect_to profile_path, notice: "You're now on Pro!"
  end

  def downgrade
    Current.user.update!(plan: "free")
    redirect_to profile_path, notice: "Downgraded to Free plan."
  end

  def activate_beta
    if params[:beta_code].to_s.strip.upcase == "VOLT-BETA"
      Current.user.update!(plan: "beta")
      redirect_to profile_path, notice: "Welcome to the Volt Beta! You now have access to all Pro features."
    else
      redirect_to profile_path, alert: "Invalid beta code. Please try again."
    end
  end
end

module User::Billing
  extend ActiveSupport::Concern

  def pro?
    plan == "pro"
  end

  def beta?
    plan == "beta"
  end

  def pro_features?
    pro? || beta?
  end

  def free?
    !pro? && !beta?
  end
end

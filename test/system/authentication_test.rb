require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "sign in and see the feed" do
    visit new_session_path

    fill_in "Enter your email address", with: users(:one).email_address
    fill_in "Enter your password", with: "password"
    click_on "Sign in"

    assert_text "VOLT"
    assert_no_text "Sign in"
  end

  test "sign in with wrong password" do
    visit new_session_path

    fill_in "Enter your email address", with: users(:one).email_address
    fill_in "Enter your password", with: "wrong"
    click_on "Sign in"

    assert_text "Sign in"
  end
end

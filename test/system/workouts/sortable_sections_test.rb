require "application_system_test_case"

module Workouts; end

class Workouts::SortableSectionsTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    fill_in "Enter your email address", with: users(:one).email_address
    fill_in "Enter your password", with: "password"
    click_on "Sign in"
    # Wait for the post-login redirect to complete so the session cookie is
    # written before the test body navigates to another protected page.
    assert_no_current_path new_session_path, wait: 5
  end

  test "drag-reordering sections persists the new order" do
    visit new_workout_path

    # The workout name field has name="name" (form_with url:, not model:)
    find("input[name='name']").set("Drag Test")

    # Add three sections named A, B, C in DOM order, each with one named exercise
    # (the exercise name input is required by HTML5 validation).
    %w[A B C].each_with_index do |section_name, idx|
      # Dispatch a programmatic click on the + Add Section button to avoid
      # viewport/scroll interception issues in headless Chrome.
      add_section_btn = find("button[data-action='builder#addSection']")
      page.execute_script("arguments[0].click()", add_section_btn)
      # Wait for the new section to appear before interacting (re-query each time
      # to avoid stale element references after JS DOM mutations).
      assert_selector "[data-builder-target='sectionsList'] > [data-section-id]",
                      count: idx + 1, wait: 5

      # Re-query the last section each time to get a fresh, non-stale reference.
      section_id = all("[data-builder-target='sectionsList'] > [data-section-id]")
                     .last["data-section-id"]
      section_selector = "[data-section-id='#{section_id}']"

      # Fill the section's name input via JS to avoid focus/interception issues.
      section_name_input = find("#{section_selector} input[name$='[name]']", match: :first)
      page.execute_script("arguments[0].value = arguments[1]", section_name_input, section_name)

      # Add one exercise via programmatic JS click to avoid scroll/viewport issues.
      add_exercise_btn = find("#{section_selector} button[data-action='builder#addExercise']")
      page.execute_script("arguments[0].click()", add_exercise_btn)
      # Wait for the exercise row to appear.
      assert_selector "#{section_selector} [data-exercise-id]", wait: 5

      # Re-query the exercise to avoid stale refs after DOM mutation.
      exercise_id = find("#{section_selector} [data-exercise-id]", match: :first)["data-exercise-id"]
      exercise_name_input = find("[data-exercise-id='#{exercise_id}'] input[name$='[name]']")
      page.execute_script("arguments[0].value = arguments[1]", exercise_name_input, "#{section_name}-Exercise")
    end

    # Sanity: section name inputs are currently in DOM order A, B, C.
    section_name_values = all(
      "[data-builder-target='sectionsList'] > [data-section-id] > div > input[name$='[name]']"
    ).map(&:value)
    assert_equal %w[A B C], section_name_values

    # Reorder sections in DOM so C comes before A.
    # This is the DOM state SortableJS produces after a drag; we verify that
    # the reindex-on-submit mechanism persists the correct order regardless of
    # which mechanism moved the DOM nodes.
    page.execute_script(<<~JS)
      const list = document.querySelector("[data-builder-target='sectionsList']");
      const items = Array.from(list.querySelectorAll(":scope > [data-section-id]"));
      // items = [A, B, C] → reorder to [C, A, B]
      list.insertBefore(items[2], items[0]);
    JS

    # DOM order should now read C, A, B.
    section_name_values = all(
      "[data-builder-target='sectionsList'] > [data-section-id] > div > input[name$='[name]']"
    ).map(&:value)
    assert_equal %w[C A B], section_name_values

    # Submit via requestSubmit() which fires the submit event (needed for
    # the sortable-sections controller's reindex listener to run).
    # Also disables HTML5 validation to avoid issues with JS-set field values.
    page.execute_script(<<~JS)
      const form = document.querySelector("form[data-controller='builder']");
      form.noValidate = true;
      form.requestSubmit();
    JS

    # Wait for the app to navigate away from the builder form, confirming save.
    assert_no_current_path new_workout_path, wait: 5

    # Persisted order must reflect the drag.
    workout = Workout.where(name: "Drag Test").last
    assert workout, "expected a workout named 'Drag Test' to be created"
    assert_equal %w[C A B], workout.structure["sections"].map { |s| s["name"] }
  end
end

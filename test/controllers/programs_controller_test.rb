require "test_helper"

class ProgramsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "show renders program with activity" do
    program = programs(:hyrox_program)
    get program_path(program)
    assert_response :success
    assert_select "p.text-lime-400", "Hyrox"
  end

  test "show renders program without activity" do
    program = programs(:no_activity_program)
    get program_path(program)
    assert_response :success
    assert_select "p.text-lime-400", "Custom"
  end

  test "retry_slot resets failed slot and enqueues job" do
    program = programs(:hyrox_program)
    pw = program.program_workouts.create!(
      week_number: 1, session_number: 2, status: "failed"
    )

    assert_enqueued_with(job: RetryProgramSlotJob, args: [pw.id]) do
      post retry_slot_program_path(program, program_workout_id: pw.id)
    end

    assert_redirected_to program_path(program)
    assert_equal "pending", pw.reload.status
  end

  test "retry_slot ignores non-failed slots" do
    program = programs(:hyrox_program)
    pw = program.program_workouts.create!(
      week_number: 1, session_number: 2, status: "complete",
      workout: workouts(:hyrox_session)
    )

    post retry_slot_program_path(program, program_workout_id: pw.id)
    assert_redirected_to program_path(program)
    assert_equal "complete", pw.reload.status
  end
end

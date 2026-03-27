class RetryProgramSlotJob < ApplicationJob
  queue_as :default

  def perform(program_workout_id)
    pw = ProgramWorkout.find(program_workout_id)
    program = pw.program

    pw.update!(status: "generating")
    broadcast_slot(pw)

    workout = WorkoutLLMGenerator.call(
      user:          program.user,
      activity:      program.activity&.name,
      duration_mins: program.duration_mins,
      difficulty:    program.difficulty,
      session_notes: pw.session_notes
    )

    pw.update!(workout: workout, status: "complete")
    broadcast_slot(pw)
  rescue => e
    Rails.logger.error "RetryProgramSlotJob failed for pw #{program_workout_id}: #{e.message}"
    pw&.update!(status: "failed")
    broadcast_slot(pw) if pw
  end

  private

  def broadcast_slot(pw)
    pw_fresh = pw.reload
    Turbo::StreamsChannel.broadcast_replace_to(
      "program_#{pw_fresh.program_id}",
      target:  pw_fresh.turbo_dom_id,
      partial: "programs/program_workout_slot",
      locals:  { program_workout: pw_fresh }
    )
  end
end

# Adds Workout.scan_from_image — extracts a structured workout from a photo
# using Claude's multimodal API.
#
#   workout = Workout.scan_from_image(image: uploaded_file, user: current_user)
#   # => unsaved Workout with structure, ready for preview
module Scannable
  extend ActiveSupport::Concern

  class ScanError < StandardError; end

  ACCEPTED_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
  MAX_IMAGE_SIZE = 5.megabytes

  SCAN_SYSTEM_PROMPT = <<~PROMPT
    You are a workout transcription assistant. You will receive a photo of a workout
    (an Instagram screenshot, a gym whiteboard, or a printed sheet). Your job is to
    extract the workout and return it as structured data using the create_workout tool.

    Rules:
    - Extract ALL exercises, sets, reps, weights, and durations visible in the image.
    - Translate common abbreviations: DB = Dumbbell, BB = Barbell, KB = Kettlebell,
      BW = Bodyweight, RFT = Rounds for Time, AMRAP = As Many Rounds As Possible,
      EMOM = Every Minute on the Minute, E2MOM = Every 2 Minutes on the Minute,
      DU = Double-Unders, SU = Single-Unders, T2B = Toes-to-Bar, C2B = Chest-to-Bar,
      HSPU = Handstand Push-Up, MU = Muscle-Up, OHS = Overhead Squat, FS = Front Squat,
      BS = Back Squat, DL = Deadlift, PC = Power Clean, SC = Squat Clean.
    - Infer reasonable defaults for missing metrics. If reps are listed but no weight,
      leave weight_kg as null. If a section has a time cap, use it as duration_mins.
    - Give the workout a punchy, imaginative name (2-4 words) if the image doesn't
      include a name.
    - Set the activity field to the detected workout style (CrossFit, HIIT, etc.).
    - If the image does NOT contain a workout, return a structure with an empty sections array.
    - Best-guess anything unclear rather than skipping it.
  PROMPT

  class_methods do
    def scan_from_image(image:, user:)
      validate_image!(image)
      data = encode_image(image)
      response = call_scan_api(data[:base64], data[:media_type])
      build_scanned_workout(response, user)
    end

    private

    def validate_image!(image)
      unless ACCEPTED_CONTENT_TYPES.include?(image.content_type)
        raise ScanError, "Please upload a JPEG, PNG, GIF, or WebP image."
      end
      raise ScanError, "Image must be under 5MB." if image.size > MAX_IMAGE_SIZE
    end

    def encode_image(image)
      raw = image.read
      {
        base64: Base64.strict_encode64(raw),
        media_type: image.content_type
      }
    end

    def call_scan_api(base64_data, media_type)
      @api_client ||= Class.new { include AnthropicApi }.new

      @api_client.call_anthropic_api(
        system: SCAN_SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: { type: "base64", media_type: media_type, data: base64_data }
              },
              {
                type: "text",
                text: "Extract the workout from this image and return it using the create_workout tool."
              }
            ]
          }
        ],
        tools: [ scan_tool ]
      )
    rescue AnthropicApi::ApiError => e
      raise ScanError, e.message
    end

    # Lazily build the scan tool definition — TOOL_DEFINITION references
    # Workout::DIFFICULTIES which isn't available at Scannable load time.
    def scan_tool
      @scan_tool ||= WorkoutLLMGenerator::TOOL_DEFINITION.deep_dup.tap do |tool|
        tool[:input_schema][:properties][:activity] = {
          type: "string",
          description: "The workout style detected (e.g. CrossFit, HIIT, Strength, Hyrox, Functional Fitness). Leave blank if unclear."
        }
      end.freeze
    end

    def build_scanned_workout(data, user)
      sections = Array(data.dig("structure", "sections"))
      raise ScanError, "No workout found in that image." if sections.empty?

      difficulty = Workout::DIFFICULTIES.include?(data["difficulty"]) ? data["difficulty"] : "intermediate"
      duration_mins = data["duration_mins"].to_i.positive? ? data["duration_mins"].to_i : 45

      # Run through validator for structural fixes
      validator = WorkoutValidator.new(data, difficulty: difficulty, duration_mins: duration_mins, main_tag_slug: nil)
      validator.validate_and_fix

      activity_name = data["activity"].presence
      activity = activity_name ? Activity.find_or_create_by!(name: activity_name) : nil

      Workout.new(
        user: user,
        name: data["name"].presence || "Scanned Workout",
        difficulty: difficulty,
        duration_mins: duration_mins,
        activity: activity,
        structure: data["structure"],
        status: "preview"
      )
    end
  end
end

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

    CRITICAL — structure vs notes:
    - ALL structural information MUST go in the structure fields, NEVER in exercise notes.
    - Number of sets/rounds → use the "rounds" field on the section, not in exercise notes.
    - Descending/ascending patterns (e.g. 300m, 200m, 100m) → use format "ladder" with
      start, end, step, and varies fields. Do NOT list each distance as a separate exercise
      or describe the pattern in notes.
    - Exercise notes are ONLY for form cues and intensity guidance (e.g. "slow pace",
      "explosive hip drive", "keep chest tall"). Never put "3 sets", "2 rounds",
      "descending", or rep/distance schemes in the notes field.
    - If a section has multiple rounds of the same exercise, set rounds on the section —
      do NOT duplicate the exercise in the exercises array.
    - One exercise entry per distinct exercise. Use the section's rounds field for repetition.
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

    # Lazily build the scan tool definition, adding an activity property for scanning.
    def scan_tool
      @scan_tool ||= WorkoutLLMGenerator::TOOL_DEFINITION.deep_dup.tap do |tool|
        tool[:input_schema][:properties][:activity] = {
          type: "string",
          description: "The workout style detected (e.g. CrossFit, HIIT, Strength, Hyrox, Functional Fitness). Leave blank if unclear."
        }
      end.freeze
    end

    def ensure_warmup_and_cooldown(sections)
      categories = sections.map { |s| s["category"].to_s.downcase }

      unless categories.any? { |c| c == "warm_up" }
        warmup = %w[Easy Row Easy Ride Easy Ski Easy Rope].sample
        sections.unshift({
          "name" => "Warm-Up",
          "category" => "warm_up",
          "format" => "straight",
          "duration_mins" => 5,
          "exercises" => [{ "name" => warmup, "notes" => "Easy pace" }]
        })
      end

      unless categories.any? { |c| c == "cool_down" }
        sections.push({
          "name" => "Cool-Down",
          "category" => "cool_down",
          "format" => "straight",
          "duration_mins" => 5,
          "exercises" => [
            { "name" => "Child Pose to Cobra", "notes" => "10 deep breaths" },
            { "name" => "Wall Hamstring Stretch", "notes" => "10 deep breaths each side" },
            { "name" => "Shoulder Stretch", "notes" => "10 deep breaths each side" }
          ]
        })
      end
    end

    def build_scanned_workout(data, user)
      sections = Array(data.dig("structure", "sections"))
      raise ScanError, "No workout found in that image." if sections.empty?

      duration_mins = data["duration_mins"].to_i.positive? ? data["duration_mins"].to_i : 45

      # Run through validator for structural fixes
      validator = WorkoutValidator.new(data, duration_mins: duration_mins, main_tag_slug: nil)
      validator.validate_and_fix

      # Add warm-up and cool-down if not present in the scanned image
      ensure_warmup_and_cooldown(sections)

      activity_name = data["activity"].presence
      activity = activity_name ? Activity.find_or_create_by!(name: activity_name) : nil

      Workout.new(
        user: user,
        name: data["name"].presence || "Scanned Workout",
        duration_mins: duration_mins,
        activity: activity,
        structure: data["structure"],
        status: "preview"
      )
    end
  end
end

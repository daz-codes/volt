# Photo-to-Workout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users photograph or screenshot a workout and have it parsed into a structured Volt workout via Claude Vision, reusing the existing preview/edit/save flow.

**Architecture:** New `Scannable` concern on `Workout` handles image→structured-workout via Claude Haiku multimodal API. Shared `AnthropicApi` module extracted from `WorkoutLLMGenerator` provides HTTP/retry logic. New `WorkoutsController#scan` action mirrors the existing `create_with_llm` cache-then-redirect preview flow.

**Tech Stack:** Rails 8, Anthropic Messages API (multimodal), Net::HTTP, existing `WorkoutValidator`

**Spec:** `docs/superpowers/specs/2026-03-29-photo-to-workout-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `app/models/concerns/anthropic_api.rb` | Create | Shared HTTP client — retry logic, request building, response parsing |
| `app/models/concerns/scannable.rb` | Create | `Workout.scan_from_image` — image encoding, prompt, validation, returns unsaved Workout |
| `app/models/workout.rb` | Modify | `include Scannable` |
| `app/services/workout_llm_generator.rb` | Modify | Replace inline `call_llm` with `include AnthropicApi` delegation |
| `app/controllers/workouts_controller.rb` | Modify | Add `scan` action |
| `app/views/workouts/_generate_modal.html.erb` | Modify | Add scan upload form |
| `app/javascript/controllers/generate_form_controller.js` | Modify | Add `submitOnFileSelect` action for auto-submit on file pick |
| `config/routes.rb` | Modify | Add `POST /workouts/scan` |
| `test/models/concerns/anthropic_api_test.rb` | Create | Unit tests for shared API module |
| `test/models/concerns/scannable_test.rb` | Create | Unit tests for scan concern |
| `test/controllers/workouts_controller_scan_test.rb` | Create | Controller tests for scan action |

---

### Task 1: Extract AnthropicApi module from WorkoutLLMGenerator

Extract the HTTP/retry/response-parsing logic from `WorkoutLLMGenerator#call_llm` (lines 2082-2144) into a shared module so both the existing generator and the new `Scannable` concern can use it.

**Files:**
- Create: `app/models/concerns/anthropic_api.rb`
- Create: `test/models/concerns/anthropic_api_test.rb`
- Modify: `app/services/workout_llm_generator.rb:2082-2144`

- [ ] **Step 1: Write the failing test for AnthropicApi**

Create `test/models/concerns/anthropic_api_test.rb`:

```ruby
require "test_helper"

class AnthropicApiTest < ActiveSupport::TestCase
  # Minimal includer class to test the module
  class FakeClient
    include AnthropicApi

    # Expose error_message_for for testing
    public :error_message_for
  end

  setup do
    @client = FakeClient.new
  end

  test "error_message_for returns rate limit message for 429" do
    assert_match(/Too many requests/, @client.error_message_for(429))
  end

  test "error_message_for returns overloaded message for 529" do
    assert_match(/overloaded/, @client.error_message_for(529))
  end

  test "error_message_for returns server error message for 500" do
    assert_match(/temporarily unavailable/, @client.error_message_for(500))
  end

  test "error_message_for returns generic message for unknown codes" do
    msg = @client.error_message_for(418)
    assert_match(/error 418/, msg)
  end

  test "call_anthropic_api raises when ANTHROPIC_API_KEY is missing" do
    original = ENV["ANTHROPIC_API_KEY"]
    ENV.delete("ANTHROPIC_API_KEY")

    assert_raises(AnthropicApi::ApiError) do
      @client.call_anthropic_api(
        messages: [{ role: "user", content: "test" }],
        tools: [{ name: "create_workout" }]
      )
    end
  ensure
    ENV["ANTHROPIC_API_KEY"] = original if original
  end
end
```

**Note:** Full HTTP integration is tested through `Scannable` tests (Task 2) which stub at the `call_scan_api` boundary. The `AnthropicApi` module tests focus on the error message logic and API key validation.

- [ ] **Step 2: Run test to verify it fails**

Run: `PATH="/opt/homebrew/bin:/Users/daz/.local/share/mise/installs/ruby/3.4.7/bin:$PATH" bin/rails test test/models/concerns/anthropic_api_test.rb`
Expected: FAIL — `NameError: uninitialized constant AnthropicApi` or similar

- [ ] **Step 3: Implement AnthropicApi module**

Create `app/models/concerns/anthropic_api.rb`:

```ruby
require "net/http"
require "json"

# Shared Anthropic Messages API client with retry logic.
# Include in any class that needs to call Claude.
#
#   class MyService
#     include AnthropicApi
#     def do_thing
#       result = call_anthropic_api(messages: [...], tools: [...])
#     end
#   end
module AnthropicApi
  extend ActiveSupport::Concern

  class ApiError < StandardError; end

  API_URI = URI("https://api.anthropic.com/v1/messages")
  DEFAULT_MODEL = "claude-haiku-4-5-20251001"
  RETRY_BACKOFFS = [ 5, 10, 20, 30, 30 ].freeze
  RETRYABLE_CODES = [ 429, 500, 502, 503, 529 ].freeze

  # Calls the Anthropic Messages API with tool use.
  #
  # Options:
  #   messages:    Array of message hashes (required)
  #   tools:       Array of tool definition hashes (required)
  #   system:      String system prompt (optional)
  #   model:       Model ID (default: claude-haiku-4-5-20251001)
  #   max_tokens:  Integer (default: 4096)
  #   tool_choice: Hash (default: { type: "any" })
  #
  # Returns the tool input hash from the first tool_use content block.
  # Raises AnthropicApi::ApiError on failure.
  def call_anthropic_api(messages:, tools:, system: nil, model: DEFAULT_MODEL,
                         max_tokens: 4096, tool_choice: { type: "any" })
    api_key = ENV.fetch("ANTHROPIC_API_KEY") { raise ApiError, "ANTHROPIC_API_KEY not configured" }

    body = {
      model: model,
      max_tokens: max_tokens,
      tools: tools,
      tool_choice: tool_choice,
      messages: messages
    }
    body[:system] = system if system.present?

    http              = Net::HTTP.new(API_URI.host, API_URI.port)
    http.use_ssl      = true
    http.open_timeout = 10
    http.read_timeout = 60

    request = Net::HTTP::Post.new(API_URI.path)
    request["Content-Type"]      = "application/json"
    request["x-api-key"]         = api_key
    request["anthropic-version"] = "2023-06-01"
    request.body = body.to_json

    retries = 0
    begin
      response = http.request(request)
      code = response.code.to_i
      unless code == 200
        if RETRYABLE_CODES.include?(code) && retries < RETRY_BACKOFFS.size
          wait = RETRY_BACKOFFS[retries]
          Rails.logger.warn "AnthropicApi #{code} — retry #{retries + 1}/#{RETRY_BACKOFFS.size} after #{wait}s"
          sleep wait
          retries += 1
          retry
        end
        raise ApiError, error_message_for(code)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      if retries < RETRY_BACKOFFS.size
        wait = RETRY_BACKOFFS[retries]
        Rails.logger.warn "AnthropicApi timeout — retry #{retries + 1}/#{RETRY_BACKOFFS.size} after #{wait}s"
        sleep wait
        retries += 1
        retry
      end
      raise ApiError, "Request timed out. Please try again."
    end

    parsed     = JSON.parse(response.body)
    tool_block = parsed["content"]&.find { |b| b["type"] == "tool_use" }
    raise ApiError, "No tool response returned by LLM" unless tool_block

    tool_block["input"]
  end

  private

  def error_message_for(code)
    case code
    when 429     then "Too many requests right now. Please try again in a moment."
    when 503, 529 then "The AI is overloaded right now. Please try again in a moment."
    when 500, 502 then "The AI service is temporarily unavailable. Please try again."
    else "AI request failed (error #{code}). Please try again."
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `PATH="/opt/homebrew/bin:/Users/daz/.local/share/mise/installs/ruby/3.4.7/bin:$PATH" bin/rails test test/models/concerns/anthropic_api_test.rb`
Expected: 5 tests, 0 failures

- [ ] **Step 5: Wire AnthropicApi into WorkoutLLMGenerator**

In `app/services/workout_llm_generator.rb`:

1. Add `include AnthropicApi` near the top of the class (after the class declaration, line 16)
2. Replace the `call_llm` method (lines 2082-2144) with a thin wrapper:

```ruby
def call_llm(prompt, tools: [ TOOL_DEFINITION ], tool_choice: { type: "any" }, max_tokens: 4096)
  @llm_calls ||= []

  result = call_anthropic_api(
    messages: [ { role: "user", content: prompt } ],
    tools: tools,
    tool_choice: tool_choice,
    model: MODEL,
    max_tokens: max_tokens
  )

  @llm_calls << { prompt: prompt, response: result }
  result
rescue AnthropicApi::ApiError => e
  raise WorkoutGenerationError, e.message
end
```

- [ ] **Step 6: Run full test suite to verify nothing is broken**

Run: `PATH="/opt/homebrew/bin:/Users/daz/.local/share/mise/installs/ruby/3.4.7/bin:$PATH" bin/rails test`
Expected: All existing tests pass (no regressions)

- [ ] **Step 7: Commit**

```bash
git add app/models/concerns/anthropic_api.rb test/models/concerns/anthropic_api_test.rb app/services/workout_llm_generator.rb
git commit -m "refactor: extract AnthropicApi module from WorkoutLLMGenerator

Shared HTTP client with retry logic (429/500/502/503/529),
exponential backoff, and tool-use response parsing. WorkoutLLMGenerator
now delegates to this module. Prepares for Scannable concern reuse."
```

---

### Task 2: Create Scannable concern

Build the `Scannable` concern that adds `Workout.scan_from_image(image:, user:)`. This sends the image to Claude's multimodal API via the shared `AnthropicApi` module, validates the result with `WorkoutValidator`, and returns an unsaved `Workout`.

**Files:**
- Create: `app/models/concerns/scannable.rb`
- Create: `test/models/concerns/scannable_test.rb`
- Modify: `app/models/workout.rb` (add `include Scannable`)

**Docs to check:**
- Anthropic multimodal API: image content blocks use `{ type: "image", source: { type: "base64", media_type: "image/jpeg", data: "<base64>" } }`
- `WorkoutValidator` initialization: `WorkoutValidator.new(data, difficulty:, duration_mins:, main_tag_slug:)`
- `TOOL_DEFINITION` in `WorkoutLLMGenerator` (lines 391-448): the `create_workout` tool schema

- [ ] **Step 1: Write failing tests for Scannable**

Create `test/models/concerns/scannable_test.rb`:

```ruby
require "test_helper"

class ScannableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @valid_tool_response = {
      "name" => "Whiteboard AMRAP",
      "duration_mins" => 30,
      "difficulty" => "intermediate",
      "activity" => "CrossFit",
      "structure" => {
        "goal" => "Complete as many rounds as possible",
        "sections" => [
          {
            "name" => "AMRAP 20",
            "format" => "amrap",
            "duration_mins" => 20,
            "exercises" => [
              { "name" => "Pull-Ups", "reps" => 10 },
              { "name" => "Push-Ups", "reps" => 20 },
              { "name" => "Air Squats", "reps" => 30 }
            ]
          }
        ]
      }
    }
  end

  test "scan_from_image returns unsaved workout with structure" do
    image = fixture_file_upload("files/workout_screenshot.jpg", "image/jpeg")

    Workout.stub(:call_scan_api, @valid_tool_response) do
      workout = Workout.scan_from_image(image: image, user: @user)

      assert_not workout.persisted?
      assert_equal "Whiteboard AMRAP", workout.name
      assert_equal 30, workout.duration_mins
      assert_equal "intermediate", workout.difficulty
      assert_equal @user, workout.user
      assert workout.structure.present?
    end
  end

  test "scan_from_image defaults difficulty when missing" do
    response = @valid_tool_response.merge("difficulty" => nil)
    image = fixture_file_upload("files/workout_screenshot.jpg", "image/jpeg")

    Workout.stub(:call_scan_api, response) do
      workout = Workout.scan_from_image(image: image, user: @user)
      assert_equal "intermediate", workout.difficulty
    end
  end

  test "scan_from_image defaults duration_mins when missing" do
    response = @valid_tool_response.merge("duration_mins" => 0)
    image = fixture_file_upload("files/workout_screenshot.jpg", "image/jpeg")

    Workout.stub(:call_scan_api, response) do
      workout = Workout.scan_from_image(image: image, user: @user)
      assert_equal 45, workout.duration_mins
    end
  end

  test "scan_from_image looks up activity from response" do
    image = fixture_file_upload("files/workout_screenshot.jpg", "image/jpeg")

    Workout.stub(:call_scan_api, @valid_tool_response) do
      workout = Workout.scan_from_image(image: image, user: @user)
      assert_equal "CrossFit", workout.activity&.name
    end
  end

  test "scan_from_image rejects files over 5MB" do
    image = fixture_file_upload("files/workout_screenshot.jpg", "image/jpeg")

    image.stub(:size, 6.megabytes) do
      assert_raises(Scannable::ScanError) do
        Workout.scan_from_image(image: image, user: @user)
      end
    end
  end

  test "scan_from_image rejects non-image content types" do
    image = fixture_file_upload("files/workout_screenshot.jpg", "text/plain")

    assert_raises(Scannable::ScanError) do
      Workout.scan_from_image(image: image, user: @user)
    end
  end

  test "scan_from_image raises ScanError on empty structure" do
    empty_response = @valid_tool_response.merge(
      "structure" => { "sections" => [] }
    )
    image = fixture_file_upload("files/workout_screenshot.jpg", "image/jpeg")

    Workout.stub(:call_scan_api, empty_response) do
      assert_raises(Scannable::ScanError) do
        Workout.scan_from_image(image: image, user: @user)
      end
    end
  end
end
```

- [ ] **Step 2: Create test fixture image**

```bash
mkdir -p test/fixtures/files
# Create a minimal 1x1 JPEG for tests
printf '\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xd9' > test/fixtures/files/workout_screenshot.jpg
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `PATH="/opt/homebrew/bin:/Users/daz/.local/share/mise/installs/ruby/3.4.7/bin:$PATH" bin/rails test test/models/concerns/scannable_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'scan_from_image' for Workout`

- [ ] **Step 4: Implement Scannable concern**

Create `app/models/concerns/scannable.rb`:

```ruby
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

  SCAN_TOOL = WorkoutLLMGenerator::TOOL_DEFINITION.deep_dup.tap do |tool|
    # Add activity field so the LLM can classify the workout
    tool[:input_schema][:properties][:activity] = {
      type: "string",
      description: "The workout style detected (e.g. CrossFit, HIIT, Strength, Hyrox, Functional Fitness). Leave blank if unclear."
    }
  end.freeze

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
      if image.size > MAX_IMAGE_SIZE
        raise ScanError, "Image must be under 5MB."
      end
    end

    def encode_image(image)
      raw = image.read
      {
        base64: Base64.strict_encode64(raw),
        media_type: image.content_type
      }
    end

    def call_scan_api(base64_data, media_type)
      # Singleton includer for the shared API module
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
        tools: [ SCAN_TOOL ]
      )
    rescue AnthropicApi::ApiError => e
      raise ScanError, e.message
    end

    def build_scanned_workout(data, user)
      sections = Array(data.dig("structure", "sections"))
      raise ScanError, "No workout found in that image." if sections.empty?

      difficulty = Workout::DIFFICULTIES.include?(data["difficulty"]) ? data["difficulty"] : "intermediate"
      duration_mins = data["duration_mins"].to_i.positive? ? data["duration_mins"].to_i : 45

      # Run through validator for structural fixes
      validator = WorkoutValidator.new(data, difficulty: difficulty, duration_mins: duration_mins)
      validator.validate_and_fix

      # Look up activity
      activity_name = data["activity"].presence
      activity = activity_name.present? ? Activity.find_or_create_by!(name: activity_name) : nil

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
```

- [ ] **Step 5: Include Scannable in Workout model**

In `app/models/workout.rb`, add after line 1:

```ruby
class Workout < ApplicationRecord
  include Scannable
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `PATH="/opt/homebrew/bin:/Users/daz/.local/share/mise/installs/ruby/3.4.7/bin:$PATH" bin/rails test test/models/concerns/scannable_test.rb`
Expected: 7 tests, 0 failures

- [ ] **Step 7: Run full suite**

Run: `PATH="/opt/homebrew/bin:/Users/daz/.local/share/mise/installs/ruby/3.4.7/bin:$PATH" bin/rails test`
Expected: All tests pass

- [ ] **Step 8: Commit**

```bash
git add app/models/concerns/scannable.rb test/models/concerns/scannable_test.rb test/fixtures/files/workout_screenshot.jpg app/models/workout.rb
git commit -m "feat: add Scannable concern — Workout.scan_from_image

Claude Vision multimodal API extracts workout structure from photos.
Validates image size/type, defaults difficulty/duration, infers activity,
runs through WorkoutValidator. Returns unsaved Workout for preview."
```

---

### Task 3: Add route and controller action

Wire up `POST /workouts/scan` to accept image uploads, call `Workout.scan_from_image`, cache the result, and redirect to the existing preview flow.

**Files:**
- Modify: `config/routes.rb:26`
- Modify: `app/controllers/workouts_controller.rb`
- Create: `test/controllers/workouts_controller_scan_test.rb`

**Docs to check:**
- Existing `create_with_llm` (lines 325-361): cache-then-redirect pattern, generation limit check, generation_uses record
- Existing `preview` (lines 99-111): reads cache, builds Workout from attrs
- Preview cache format: `{ attrs: { name:, activity_id:, duration_mins:, difficulty:, structure:, session_notes: }, debug_info:, group_tag_name: }`

- [ ] **Step 1: Write failing controller tests**

Create `test/controllers/workouts_controller_scan_test.rb`:

```ruby
require "test_helper"

class WorkoutsControllerScanTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
    @image = fixture_file_upload("files/workout_screenshot.jpg", "image/jpeg")
    @valid_response = {
      "name" => "Scanned AMRAP",
      "duration_mins" => 30,
      "difficulty" => "intermediate",
      "activity" => "CrossFit",
      "structure" => {
        "sections" => [
          { "name" => "AMRAP", "format" => "amrap", "duration_mins" => 20,
            "exercises" => [{ "name" => "Burpees", "reps" => 10 }] }
        ]
      }
    }
  end

  test "scan redirects to preview on success" do
    Workout.stub(:call_scan_api, @valid_response) do
      post scan_workouts_path, params: { image: @image }
    end
    assert_response :redirect
    assert_match %r{workouts/preview/}, response.location
  end

  test "scan creates generation_uses record" do
    Workout.stub(:call_scan_api, @valid_response) do
      assert_difference "@user.generation_uses.count", 1 do
        post scan_workouts_path, params: { image: @image }
      end
    end
  end

  test "scan redirects with error when generation limit reached" do
    User::FREE_GENERATION_LIMIT.times { @user.generation_uses.create! }

    post scan_workouts_path, params: { image: @image }
    assert_redirected_to root_path
    assert_match(/generations this week/, flash[:alert])
  end

  test "scan redirects with error on invalid image type" do
    bad_image = fixture_file_upload("files/workout_screenshot.jpg", "text/plain")

    post scan_workouts_path, params: { image: bad_image }
    assert_redirected_to root_path
    assert_match(/JPEG, PNG, GIF, or WebP/, flash[:alert])
  end

  test "scan redirects with error when no image provided" do
    post scan_workouts_path
    assert_redirected_to root_path
    assert_match(/upload an image/, flash[:alert])
  end

  test "scan redirects with error on API failure" do
    Workout.stub(:call_scan_api, ->(*) { raise Scannable::ScanError, "AI is overloaded" }) do
      post scan_workouts_path, params: { image: @image }
    end
    assert_redirected_to root_path
    assert_match(/overloaded/, flash[:alert])
  end

  test "scan requires authentication" do
    sign_out
    post scan_workouts_path, params: { image: @image }
    assert_response :redirect
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `PATH="/opt/homebrew/bin:/Users/daz/.local/share/mise/installs/ruby/3.4.7/bin:$PATH" bin/rails test test/controllers/workouts_controller_scan_test.rb`
Expected: FAIL — `ActionController::RoutingError: No route matches [POST] "/workouts/scan"`

- [ ] **Step 3: Add route**

In `config/routes.rb`, modify the workouts resource block (line 26):

```ruby
resources :workouts, only: [ :new, :create, :show, :edit, :update, :destroy ] do
  collection do
    post :scan
  end
  member do
    get   :log
    get   :export_pdf
    patch :save_template
    post  :like, to: "workout_likes#toggle"
    post  :clone
    post  :remix
    post  :save
    post  :regenerate
    post  :swap_exercise
  end
end
```

- [ ] **Step 4: Add scan action to WorkoutsController**

In `app/controllers/workouts_controller.rb`, add the `scan` action after `create_with_llm` (after line 361):

```ruby
def scan
  unless params[:image].present?
    redirect_to root_path, alert: "Please upload an image."
    return
  end

  if Current.user.generation_limit_reached?
    redirect_to root_path, alert: "You've used all #{Current.user.generation_limit} generations this week. Upgrade to Pro for unlimited workouts."
    return
  end

  workout = Workout.scan_from_image(image: params[:image], user: Current.user)

  token = SecureRandom.urlsafe_base64(16)
  Rails.cache.write("workout_preview:#{token}", {
    attrs: {
      name: workout.name,
      activity_id: workout.activity_id,
      duration_mins: workout.duration_mins,
      difficulty: workout.difficulty,
      structure: workout.structure
    },
    debug_info: nil,
    group_tag_name: nil
  }, expires_in: 1.hour)

  Current.user.generation_uses.create!
  redirect_to preview_workout_path(token: token)
rescue Scannable::ScanError => e
  redirect_to root_path, alert: e.message
rescue => e
  Rails.logger.error "Workout scan failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  redirect_to root_path, alert: "Something went wrong scanning your workout. Please try again."
end
```

Also add `scan` to any `before_action` authentication filter that covers `create`. Check the existing `before_action` filters and ensure `scan` is included.

- [ ] **Step 5: Run tests to verify they pass**

Run: `PATH="/opt/homebrew/bin:/Users/daz/.local/share/mise/installs/ruby/3.4.7/bin:$PATH" bin/rails test test/controllers/workouts_controller_scan_test.rb`
Expected: 7 tests, 0 failures

- [ ] **Step 6: Run full suite**

Run: `PATH="/opt/homebrew/bin:/Users/daz/.local/share/mise/installs/ruby/3.4.7/bin:$PATH" bin/rails test`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/workouts_controller.rb test/controllers/workouts_controller_scan_test.rb
git commit -m "feat: add POST /workouts/scan controller action

Accepts image upload, calls Workout.scan_from_image, caches result
with preview token, records generation use, redirects to existing
preview flow. Enforces generation limit and auth."
```

---

### Task 4: Add UI entry point in generate modal

Add a "Scan a workout photo" upload form to the generate modal, positioned below the submit button. Uses a separate `<form>` that posts to `/workouts/scan` with a file input.

**Files:**
- Modify: `app/views/workouts/_generate_modal.html.erb`

- [ ] **Step 1: Add scan upload form to generate modal**

In `app/views/workouts/_generate_modal.html.erb`, add the scan form **after** the closing `<% end %>` of the main form (after line 174) and **before** the upgrade CTAs (before line 176):

```erb
  <%# Scan a workout photo — separate form posting to /workouts/scan %>
  <% unless user_at_limit %>
    <div class="relative my-4">
      <div class="absolute inset-0 flex items-center"><div class="w-full border-t border-zinc-700"></div></div>
      <div class="relative flex justify-center"><span class="bg-zinc-900 px-3 text-xs text-gray-500 uppercase tracking-wide">or</span></div>
    </div>

    <%= form_with url: scan_workouts_path, multipart: true, data: { controller: "generate-form", action: "submit->generate-form#showSpinner" } do %>
      <label class="flex items-center justify-center gap-2 w-full border-2 border-dashed border-zinc-600 hover:border-lime-400/50 rounded-xl py-3.5 cursor-pointer transition-colors group">
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-gray-500 group-hover:text-lime-400 transition-colors">
          <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
          <circle cx="12" cy="13" r="4"/>
        </svg>
        <span class="text-sm font-bold text-gray-400 group-hover:text-lime-400 transition-colors">Scan a workout photo</span>
        <input type="file" name="image" accept="image/jpeg,image/png,image/gif,image/webp"
               class="sr-only" data-action="change->generate-form#submitOnFileSelect">
      </label>
    <% end %>
  <% end %>
```

This renders:
- A divider line with "or" centered
- A dashed-border upload area with a camera icon
- Hidden file input that auto-submits when a file is selected via Stimulus
- Reuses the `generate-form` Stimulus controller for the spinner
- Hidden when user is at generation limit (same as submit button)

- [ ] **Step 2: Add submitOnFileSelect to generate-form Stimulus controller**

In `app/javascript/controllers/generate_form_controller.js`, add a new action method:

```javascript
submitOnFileSelect(event) {
  if (event.target.files.length > 0) {
    this.showSpinner()
    event.target.form.requestSubmit()
  }
}
```

This auto-submits the scan form when a file is selected and shows the loading spinner.

- [ ] **Step 3: Verify manually in browser**

Run: `PATH="/opt/homebrew/bin:/Users/daz/.local/share/mise/installs/ruby/3.4.7/bin:$PATH" bin/rails server`

1. Open the generate modal
2. Verify "Scan a workout photo" appears below "Generate Workout" button
3. Verify the upload button has a camera icon and dashed border
4. Verify it's hidden when at generation limit

- [ ] **Step 4: Run full test suite**

Run: `PATH="/opt/homebrew/bin:/Users/daz/.local/share/mise/installs/ruby/3.4.7/bin:$PATH" bin/rails test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add app/views/workouts/_generate_modal.html.erb app/javascript/controllers/generate_form_controller.js
git commit -m "feat: add 'Scan a workout photo' upload to generate modal

Dashed upload area with camera icon below Generate button. File input
auto-submits on selection via Stimulus, posts to /workouts/scan.
Hidden when user is at generation limit."
```

---

## Post-Implementation Checklist

After all tasks are complete:

- [ ] Full test suite passes: `bin/rails test`
- [ ] RuboCop clean: `bin/rubocop`
- [ ] No Brakeman warnings: `bin/brakeman --no-pager`
- [ ] Manual smoke test: upload a screenshot of a workout, verify preview, edit, save

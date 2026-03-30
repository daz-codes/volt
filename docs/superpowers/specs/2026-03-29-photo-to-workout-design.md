# Photo-to-Workout — Design Spec

## Goal

Allow users to photograph or screenshot a workout (mainly Instagram posts, occasionally gym whiteboards) and have it automatically parsed into a structured Volt workout they can preview, edit, and save.

## Constraints

- Counts against the user's weekly generation limit (Free: 5/week)
- Best-guess unclear items — no flagging or skipping, user fixes on preview screen
- Primary input: Instagram screenshots (clean digital text). Secondary: handwritten whiteboards
- Must reuse existing preview/edit flow and validation pipeline

## Approach

**Claude Vision — single multimodal API call.** Send the image directly to Claude Haiku's multimodal endpoint with the same tool-use pattern (`workout_builder` tool) already used by `WorkoutLLMGenerator`. One call extracts text and returns structured workout JSON. No new dependencies.

## Architecture

### New: `Scannable` concern on `Workout`

`app/models/concerns/scannable.rb`

Encapsulates the image scanning behavior. Mixed into `Workout` so the call site reads:

```ruby
Workout.scan_from_image(image: uploaded_file, user: current_user)
```

Responsibilities:
- Validate image: reject files over 5MB, verify content type is JPEG, PNG, GIF, or WebP
- Base64-encode the uploaded image, detect media type from content type
- Build system prompt and user message with image content block
- Send to Claude Haiku (`claude-haiku-4-5-20251001`) multimodal API with `workout_builder` tool
- Extract `difficulty` and `duration_mins` from LLM response, falling back to `"intermediate"` and `45` if missing/invalid
- Infer activity from LLM response (tool includes an `activity` field) — look up matching `Activity` record, nil if no match
- Run response through existing `WorkoutValidator`
- Return an unsaved `Workout` populated with structure, activity, difficulty, duration_mins

### Shared API client

The existing `WorkoutLLMGenerator#call_llm` contains ~60 lines of HTTP setup, retry logic (5 retries with exponential backoff), and error handling (429, 503, 529, 500, 502). Rather than duplicate this, extract a shared `AnthropicClient` concern or module that both `Scannable` and `WorkoutLLMGenerator` can use. This extraction happens as part of this feature's implementation.

### API Message Format

The multimodal request uses the standard Anthropic messages API with an image content block:

```ruby
{
  role: "user",
  content: [
    { type: "image", source: { type: "base64", media_type: "image/jpeg", data: base64_data } },
    { type: "text", text: "Extract the workout from this image..." }
  ]
}
```

Media type is determined from the uploaded file's content type. Max image size: 5MB (validated before encoding).

### Prompt Design

The system prompt must instruct the LLM to:
- Extract all exercises, sets, reps, weights, and durations from the image
- Translate common abbreviations: DB = dumbbell, BB = barbell, KB = kettlebell, BW = bodyweight, RFT = rounds for time, AMRAP = as many rounds as possible, E2MOM/EMOM = every minute on the minute
- Infer reasonable defaults for missing metrics (e.g., if reps listed but no weight, leave weight_kg null)
- Structure output as sections with exercises using the `workout_builder` tool schema
- Include an `activity` hint field so the workout can be categorized
- If the image does not contain a workout, return an empty structure (triggers "no workout found" error)

### Route

```ruby
# config/routes.rb
resources :workouts do
  collection do
    post :scan
  end
end
```

`POST /workouts/scan`

### Controller

`WorkoutsController#scan`:
- Receives uploaded image via `params[:image]`
- Checks generation limit (same guard as existing `create_with_llm`)
- Calls `Workout.scan_from_image(image: params[:image], user: Current.user)`
- On success: caches the result with a preview token and redirects to `preview_workout_path(token: token)` — same cache-then-redirect pattern as `create_with_llm`
- On success: creates a `generation_uses` record (same as `create_with_llm`)
- On failure: redirects back with error flash

### UI Entry Point

In the generate modal (`_generate_modal.html.erb`), add a secondary action:

- Camera/upload icon with "Scan a workout photo" label
- Standard file input accepting image types (`image/jpeg, image/png, image/gif, image/webp`)
- Submits to `POST /workouts/scan`
- Shows loading spinner ("Scanning workout...") while processing

### Preview & Save

Reuses the existing preview flow exactly:
- User sees the parsed workout in the same editable preview
- Can swap exercises, adjust sets/reps/weights
- Saves to library like any generated workout

## Data Flow

```
User selects image in generate modal
  → POST /workouts/scan (multipart form)
  → WorkoutsController#scan
    → Check generation limit
    → Workout.scan_from_image(image:, user:)
      → Validate file size & type
      → Base64 encode image, detect media type
      → Claude Haiku multimodal API (image + workout_builder tool)
      → Extract difficulty, duration_mins, activity (with defaults)
      → WorkoutValidator fixes
      → Unsaved Workout with structure
    → Cache workout with preview token
    → Create generation_uses record
    → Redirect to preview_workout_path(token:)
  → User edits & saves via existing preview flow
```

## Error Handling

- File too large (>5MB): redirect with "Image must be under 5MB"
- Invalid file type: redirect with "Please upload a JPEG, PNG, GIF, or WebP image"
- API failure: redirect with "Couldn't scan that image, please try again"
- Unparseable image (empty structure returned): redirect with "No workout found in that image"
- Generation limit reached: same guard as existing generation flow

## Testing

- Concern unit tests: mock the API call, verify structured output and validator integration
- Concern unit tests: verify defaults for missing difficulty/duration_mins
- Concern unit tests: verify file size and type validation
- Controller test: verify scan action accepts image upload, redirects to preview
- Controller test: verify generation_uses record created on success
- Controller test: verify generation limit is enforced
- Controller test: verify error handling on API failure and invalid files

# Export Modal — Design Spec

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace direct PDF export links with an export modal offering Image (PNG) and PDF downloads, both pro-gated.

**Architecture:** A `<dialog>` modal (matching existing app pattern) with two download buttons. Image generation uses MiniMagick to draw the approved whiteboard poster design server-side. PDF uses the existing `WorkoutPdfGenerator` unchanged.

**Tech Stack:** MiniMagick (ImageMagick), Prawn (existing), HTML5 `<dialog>`, Turbo

---

## 1. Export Modal UI

A new shared partial `app/views/shared/_export_dialog.html.erb` renders a `<dialog>` element following the existing pattern (see `_complete_workout_dialog.html.erb`, `_share_dialog.html.erb`).

**Accepts local:** `workout`

**Layout:**
- Dialog header: "Export" title + close button (X)
- Two option cards, stacked vertically:
  - **Image** — download icon + "Image" label + "1080 x 1350 PNG" subtitle + download link
  - **PDF** — document icon + "PDF" label + "Full workout details" subtitle + download link
- Footer note: "More export options coming soon" (placeholder for future Instagram integration)

**Styling:** Same dark theme as other dialogs — `bg-zinc-800 border-zinc-600 text-white`, lime accent on hover. Each option card is a full-width rounded button/link.

**Links:**
- Image: `GET /workouts/:id/export_image` with `data: { turbo: false }` (triggers download)
- PDF: `GET /workouts/:id/export_pdf` with `data: { turbo: false }` (existing route, unchanged)

**Pro gating in modal:** Both buttons are always visible. If user is not pro, buttons show a lock icon and link to the subscription upgrade page instead of the export URL.

## 2. Export Button Changes

All existing export PDF buttons/links across 4 locations become "Export" buttons that open the modal:

| Location | File | Current behaviour | New behaviour |
|----------|------|-------------------|---------------|
| Feed card | `feed/_workout_log_card.html.erb` | Direct PDF link (pro only, hidden for free) | Export icon visible to all, opens modal |
| Library card | `workouts/index.html.erb` | Direct PDF link (pro only, hidden for free) | Export icon visible to all, opens modal |
| Workout show (_preview) | `workouts/_preview.html.erb` | Direct PDF link (pro only, hidden for free) | "Export" button visible to all, opens modal |
| Workout log show | `workout_logs/show.html.erb` | PDF link (pro) or locked button (free) | Export icon visible to all, opens modal |

The export button is always visible (encourages upgrade). The modal handles pro gating per-option.

**Opening the modal:** `document.getElementById('export_dialog_<workout_id>').showModal()` — same pattern as complete workout dialog.

**Dialog placement:** Render `_export_dialog` partial adjacent to each export button location. Each dialog has a unique ID based on workout ID.

## 3. Image Generation — `Workout::Exportable` Concern

A new model concern `app/models/concerns/exportable.rb` on `Workout`.

**Public method:** `Workout#generate_share_image` — returns PNG binary data (String).

**Approach:** Uses MiniMagick to composite text onto a dark canvas. This replicates the approved whiteboard poster layout from `share_card.html.erb`:

- **Canvas:** 1080x1350px, background `#18181b`
- **Subtle gradient:** radial overlay at top-left (lime tint, 4% opacity)
- **Header row:** activity type (left, gray, 13px equiv) + duration (right, light gray, 14px equiv)
- **Workout name:** large bold uppercase, white, ~36px equiv scaled to 1080w
- **Lime divider:** horizontal gradient line
- **Sections:** lime green section labels (TABATA, EMOM 16MIN, etc.) + white exercise lines
- **Footer:** "VOLT" in lime, bottom-left

**Font:** Helvetica Neue Bold/Heavy (available on macOS and most Linux via fontconfig). Falls back to Helvetica or DejaVu Sans Bold.

**Text sizing (scaled for 1080w canvas, ~2.77x the 390px HTML preview):**
- Activity type label: ~36pt
- Duration: ~39pt
- Workout name: ~100pt
- Section label: ~36pt
- Exercise line: ~50pt
- Brand: ~50pt

**Section data extraction:** Same logic as `share_card.html.erb` — filter out warm-up/cool-down/stretch/recovery sections, build format labels, build exercise metric strings. Extract this into a shared private method on the concern so both the HTML view and image generator use identical logic.

**MiniMagick approach:**
```ruby
MiniMagick::Tool::Convert.new do |img|
  img.size "1080x1350"
  img.xc "#18181b"
  # Draw text elements with -annotate
  # Draw lime divider with -draw "rectangle ..."
  img.format "png"
  img << output_path
end
```

Uses a Tempfile for output, reads bytes, returns them.

## 4. Controller Action — `export_image`

**In `WorkoutsController`:**

```ruby
def export_image
  unless Current.user.pro_features?
    redirect_to workout_path(params[:id]), alert: "Image export is a Pro feature."
    return
  end
  @workout = Workout.find(params[:id])
  image_data = @workout.generate_share_image
  filename = "volt-#{@workout.name.parameterize}-#{Date.today}.png"
  send_data image_data, filename: filename, type: "image/png", disposition: "attachment"
end
```

## 5. Route

Add `get :export_image` to the workouts member routes (alongside existing `export_pdf`):

```ruby
member do
  # ...existing...
  get :export_image
  get :export_pdf
  get :share_card
  # ...
end
```

## 6. What Stays Unchanged

- `WorkoutPdfGenerator` — no changes
- `export_pdf` controller action — no changes
- `share_card.html.erb` — kept as browser preview (useful for development/debugging)
- `share_card` route and action — kept

## 7. Future (Deferred)

- Instagram API direct posting — requires OAuth flow, Meta app review
- Other social platforms
- Custom branding/theming on share cards

## Data Flow

```
User clicks Export button → dialog opens
  → clicks Image → GET /workouts/:id/export_image
    → controller checks pro_features?
    → Workout#generate_share_image (MiniMagick)
    → send_data PNG → browser downloads file

  → clicks PDF → GET /workouts/:id/export_pdf
    → controller checks pro_features? (existing)
    → WorkoutPdfGenerator#generate (existing)
    → send_data PDF → browser downloads file
```

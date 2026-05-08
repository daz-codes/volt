# Sortable workout sections

Date: 2026-05-08
Status: Draft

## Problem

In the workout builder (`app/views/workouts/_builder_form.html.erb`), users can add and remove sections, but the only way to change order is the "insert section above" up-arrow on each section header. That control is precise but slow, hard to discover, and useless once a section already exists below — you can't move an existing section *down*. Users want to reorder sections by dragging them.

## Goal

Let users reorder workout sections by drag-and-drop while editing or creating a workout. New sections always append at the bottom; reorder happens via drag.

## Non-goals

- **Drag-reorder of exercises within a section.** Sections only for this iteration.
- **Drag exercises between sections.**
- **Keyboard reorder (focus grip + arrow keys).** Out of scope; can be layered on later.
- **Persisting partial reorder state** before form submit. The form is the source of truth; order is committed on save like any other field.

## Solution overview

Introduce Sortable.js as an importmap dependency and wire it up via a small dedicated Stimulus controller (`sortable-sections`) attached to the existing sections list container. A grip handle is added at the far left of each section's header row; only the handle initiates a drag. The "insert section above" button is removed since drag fully supersedes it. No server-side or schema changes are required — DOM order on submit already drives section order through Rails param parsing.

## Affected code

- `config/importmap.rb` — pin `sortablejs`
- `app/javascript/controllers/sortable_sections_controller.js` — new file
- `app/javascript/controllers/builder_controller.js` — remove `insertSectionAbove()`; remove the up-arrow from `sectionTemplate(id)`; add the grip handle markup to `sectionTemplate(id)`
- `app/views/workouts/_builder_form.html.erb` — add `data-controller="sortable-sections"` to the sections list; add grip handle to pre-rendered sections; remove the "insert section above" button from pre-rendered sections
- `test/system/...` (or equivalent) — system test covering drag reorder + persisted order

## Detailed design

### 1. Dependency

Pin Sortable.js via importmap:

```
bin/importmap pin sortablejs
```

This adds a single `pin "sortablejs"` line to `config/importmap.rb` pointing to the JSPM-hosted ESM build. No Node toolchain change.

### 2. New controller — `sortable_sections_controller.js`

Mounts on the sections list container and instantiates one `Sortable` against `this.element`. Lifecycle is bound to Stimulus `connect`/`disconnect` so Turbo navigations don't leak instances.

```js
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  connect() {
    this.sortable = Sortable.create(this.element, {
      handle: "[data-sortable-handle]",
      animation: 150,
      ghostClass: "opacity-40",
      chosenClass: "ring-2",
      forceFallback: false
    })
  }

  disconnect() {
    this.sortable?.destroy()
    this.sortable = null
  }
}
```

Notes:
- `handle` ensures clicks on inputs, selects, and the trash button never start a drag.
- `animation: 150` gives a smooth swap as siblings move out of the way.
- `ghostClass` styles the placeholder slot during drag.
- `chosenClass` adds a ring outline to the picked-up card.
- No `onEnd` callback needed — the DOM is the model, and submission order follows DOM order.

### 3. Markup — sections list container

In `_builder_form.html.erb`, the list element gets the new controller alongside its existing target attribute:

```erb
<div data-builder-target="sectionsList" data-controller="sortable-sections" class="space-y-4 mb-4">
```

Sections are already direct children of this element — no wrapper changes needed.

### 4. Grip handle

A small `⋮⋮` grip (lucide `grip-vertical`-style SVG) is added at the far left of each section's header row, marked `data-sortable-handle`. It is rendered as a `<span>` (not a `<button>`) so it stays out of tab order and doesn't intercept clicks; it has `aria-label="Drag to reorder"` and a `title` for hover affordance, with `cursor-grab` / `active:cursor-grabbing`.

The handle must be added in **two places** since the builder uses both server-rendered ERB and a JS template string:

1. **Pre-rendered sections** in `_builder_form.html.erb` (the `existing_sections.each_with_index` loop).
2. **`sectionTemplate(id)`** in `builder_controller.js` for sections added at runtime.

Both must produce identical markup so the controller works on both kinds of sections.

Approximate markup:

```html
<span data-sortable-handle aria-label="Drag to reorder" title="Drag to reorder"
  class="text-gray-600 hover:text-lime-400 transition-colors flex-shrink-0 p-1 cursor-grab active:cursor-grabbing">
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24"
       fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <circle cx="9" cy="5" r="1"/><circle cx="9" cy="12" r="1"/><circle cx="9" cy="19" r="1"/>
    <circle cx="15" cy="5" r="1"/><circle cx="15" cy="12" r="1"/><circle cx="15" cy="19" r="1"/>
  </svg>
</span>
```

### 5. Remove "insert section above"

The up-arrow button (the one with `data-action="builder#insertSectionAbove"`) is removed from:

- The pre-rendered ERB loop in `_builder_form.html.erb`
- `sectionTemplate(id)` in `builder_controller.js`

The corresponding `insertSectionAbove()` method on `builder_controller.js` is deleted. New sections always append at the bottom via the existing `addSection()` action; users drag to reorder.

### 6. Header row order after change

Final left-to-right header order:

`grip` · name input · category select · format select · trash

This drops the up-arrow that previously sat between the format select and the trash icon.

## Why no server change

Section field names use the form `sections[<id>][...]` where `<id>` is a timestamp (or stable index for pre-rendered sections). Browsers serialise form fields in DOM order, and Rails param parsing preserves the order keys are first encountered. So when Sortable rearranges DOM nodes, the resulting params arrive at the controller in the new visual order — and `Workout::StructureBuilder` already iterates `sections` in that same order to build the structure JSON. No re-indexing or hidden position field is needed.

This invariant should be **explicitly tested** (see Testing) so a future refactor that breaks DOM-order serialisation is caught immediately.

## Edge cases

- **Single section.** Sortable instantiates fine but there is nothing to reorder. No special handling.
- **Empty list.** `addSection` adds first child; subsequent sections are draggable from then on. No special handling.
- **Drag interrupted (escape, page nav).** Sortable cleans up its own state. Stimulus `disconnect` destroys the instance on Turbo navigation.
- **Fields edited mid-drag.** Not possible — drag captures pointer until release. Field values are preserved on DOM move (browser keeps node identity).
- **Touch + scroll on mobile.** `handle` constraint means scrolling the page works normally; only pressing the grip starts a drag. Sortable handles touch natively.

## Testing

**System test** (Capybara + headless Chrome with drag support):

1. Build a workout with three named sections: A, B, C.
2. Use Capybara's drag-and-drop on section C's grip handle to a position above A.
3. Submit the form.
4. Assert the persisted `workout.structure["sections"]` order is `[C, A, B]`.

If Capybara drag is flaky in CI for this Sortable setup, fall back to a Stimulus-controller unit test that asserts `Sortable.create` is called with the expected options on `connect`, plus a controller-level test that constructs params with reordered sections and asserts `StructureBuilder` honours that order. The latter already passes today — its inclusion is to lock the invariant in place.

**Manual QA checklist:**

- Drag sections up and down on desktop; save; reload edit page; order is persisted.
- Drag on iOS Safari and Android Chrome; vertical scroll still works when starting from a non-handle area.
- Drag a section while another input is focused; release; focus state is sane.
- Add a new section; drag it to the top; save; order is correct.
- Edit an existing workout; drag a pre-rendered section; save; order is correct (this exercises both pre-rendered ERB markup and the JS-template path on the same page).

## Risks

- **Sortable.js ESM via importmap CDN.** First-time build pulls from JSPM; if offline or CDN slow, page may stall briefly. Mitigation: standard importmap caching applies; acceptable for an editor-only feature.
- **Tailwind classes used in `ghostClass` / `chosenClass`** must already be reachable by JIT. `opacity-40` and `ring-2` are standard utilities present elsewhere; safe.
- **Form re-submission order invariant.** Documented and tested as called out above.

## Rollout

Single PR. No feature flag, no migration, no data backfill. Ship behind normal review.

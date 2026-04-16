# Imperial Unit Preference for Profile Measurements

## Goal

Allow users to enter and view their height and weight in imperial units (feet/inches, pounds) instead of metric (cm, kg). The database continues to store metric values; imperial is a display-layer concern.

## Scope

**In scope:** Height and weight on the profile edit form and profile show page.

**Out of scope:** Workout exercise distances and weights (future feature). LLM generator, validator, share images, and exportable module are unaffected.

## Architecture

### Database

Add `unit_system` string column to `users` table, default `"metric"`. Allowed values: `"metric"`, `"imperial"`. No model validation added (consistent with existing `speed_unit` column pattern).

### Conversion Logic

A `UnitConversionHelper` view helper module (in `app/helpers/unit_conversion_helper.rb`) provides:

- `cm_to_ft_in(cm)` — returns `[feet, inches]` (inches rounded to nearest integer). Always returns both components, e.g. `[6, 0]` for exactly 6 feet.
- `ft_in_to_cm(feet, inches)` — returns integer cm
- `kg_to_lbs(kg)` — returns float lbs, rounded to nearest 0.5 (i.e. `(val * 2).round / 2.0`)
- `lbs_to_kg(lbs)` — returns float kg

Conversion constants:
- 1 inch = 2.54 cm
- 1 lb = 0.453592 kg

The Stimulus controller duplicates these constants client-side for the on-submit conversion. This is intentional — keeping two simple constants in sync is preferable to injecting them via data attributes.

### Profile Edit Form

- Add a **Metric / Imperial** radio toggle in the Preferences section, using the same card-style radio buttons as Speed Unit.
- A Stimulus controller (`unit-toggle`) handles the toggle:
  - When **metric** is selected: show the existing `height_cm` (cm) and `weight_kg` (kg) fields.
  - When **imperial** is selected: hide the metric fields and show `height_ft` + `height_in` (feet/inches) and `weight_lbs` (pounds) fields instead.
  - On form submit, if imperial is active, the Stimulus controller converts the imperial values to metric and writes them into the hidden `height_cm` and `weight_kg` fields before the form submits. The server always receives metric values.
  - When toggling back to metric, the metric fields retain their original server-rendered values — no re-conversion from imperial.
  - When the form loads in imperial mode, pre-populate the imperial fields by converting the existing metric values (done server-side in the ERB template using the helper).

**Imperial field constraints:**
- `height_ft`: number, min 3, max 8
- `height_in`: number, min 0, max 11
- `weight_lbs`: number, min 66, max 660, step 0.5

**Layout:** The existing 3-column grid (Age, Height, Weight) stays. In imperial mode, the Height cell contains two side-by-side sub-fields (ft + in) within the same grid cell. Weight remains a single field, just with "lbs" suffix instead of "kg".

### Profile Show Page

The Physical stats section uses the view helper to display height and weight in the user's preferred unit system:

- **Metric:** `180cm` / `80kg` (current behaviour, no space before unit)
- **Imperial:** `5'11"` / `176lbs` (no space before unit, always show both feet and inches including `6'0"`)

### Profiles Controller

- Add `unit_system` to `profile_params` permit list.
- No other controller changes needed — the form always submits `height_cm` and `weight_kg` in metric.

### What Stays Unchanged

- `height_cm` and `weight_kg` columns remain the source of truth.
- `speed_unit` toggle stays independent — not linked to `unit_system`. Users may prefer metric for running distances but imperial for body measurements.
- LLM generator, workout validator, share image generation, exportable module, workout views — no changes.
- Existing users default to metric with no migration of preferences.

## Files Affected

| File | Change |
|------|--------|
| `db/migrate/xxx_add_unit_system_to_users.rb` | Add `unit_system` string column |
| `app/helpers/unit_conversion_helper.rb` | New helper with conversion methods |
| `app/views/profiles/edit.html.erb` | Add unit toggle, conditional height/weight fields |
| `app/views/profiles/show.html.erb` | Use helper for display formatting |
| `app/javascript/controllers/unit_toggle_controller.js` | Stimulus controller for field swapping and conversion on submit |
| `app/controllers/profiles_controller.rb` | Permit `unit_system` param |
| `test/helpers/unit_conversion_helper_test.rb` | Unit tests for conversion methods |

## Edge Cases

- **No height/weight set:** Imperial fields show empty, no conversion needed.
- **Rounding:** Converting back and forth may lose sub-centimeter precision. This is acceptable — height and weight are approximate values. `kg_to_lbs` uses nearest-0.5 rounding: `(val * 2).round / 2.0`.
- **Existing users:** Default to metric. No data migration needed.
- **Zero inches:** Display as `6'0"`, never omit the inches component.
- **Toggle back to metric:** Metric fields keep original server values, not re-converted from imperial.

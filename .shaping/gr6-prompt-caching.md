---
shaping: true
---

# GR6: Prompt Caching & Modular Prompts — Shaping

## Problem

Every workout generation sends the full prompt (~6,000–8,000 tokens of input) to Claude Haiku, even though ~80% of the content is identical across requests. The format definitions, naming rules, exercise variety rules, and tool schema are the same every time. Only the session-specific parts change (user context, activity type, session notes, difficulty, duration).

This is wasteful — both in cost and latency. The prompt has also grown organically into a single monolithic string built by `build_prompt`, making it hard to maintain and reason about which rules apply to which session types.

## Outcome

- Significantly reduced input token cost per generation (target: 50–90% reduction via caching)
- Faster response times (cached prefixes skip prompt processing)
- Cleaner, more maintainable prompt architecture where session-type-specific rules are isolated
- No change to workout quality — output should be identical or better

---

## Requirements (R)

| ID | Requirement | Status |
|----|-------------|--------|
| R0 | Reduce per-request input token cost | Core goal |
| R1 | Use Anthropic prompt caching (cache_control breakpoints) | Must-have |
| R2 | Static rules (formats, naming, exercise variety) go in a cacheable system prompt | Must-have |
| R3 | Session-type-specific rules only sent for that session type (not all types every time) | Must-have |
| R4 | User context, session notes, and per-request randomness stay in the user message | Must-have |
| R5 | Tool definitions are cacheable (they're static) | Must-have |
| R6 | No regression in workout quality | Must-have |
| R7 | Functional Muscle's complex rules remain intact and correctly scoped | Must-have |
| R8 | Works with current Net::HTTP API call (no gem dependency) | Nice-to-have |
| R9 | Prompt components are individually testable / readable | Nice-to-have |

---

## Shape A: System Prompt + Cached Tools

Split the current single user message into a **cached system prompt** (static rules) + **dynamic user message** (per-request context).

| Part | Mechanism |
|------|-----------|
| **A1** | **System prompt: universal rules** — Move format definitions (tabata, emom, amrap, rounds, ladder, etc.), naming rules, exercise variety rules, rep count rules, section name rules, and the tool schema description into a `system` message with `cache_control: { type: "ephemeral" }`. This is ~3,000–4,000 tokens that never change. |
| **A2** | **System prompt: session-type rules** — After the universal block, append session-type-specific rules as a second system block. For FM: the full functional_muscle_rule + archetype. For Ohm: no warm-up/cool-down rules. For Dynamo: bodyweight-only. For Hyrox/Deka: station constraints + race sim rules. Only the relevant block is sent. Also cached (same session type = cache hit). |
| **A3** | **System prompt: sport context file** — The relevant `.md` context file (e.g. `hiit.md`, `functional_muscle.md`) as a third system block, also cached. |
| **A4** | **Tool definition caching** — Mark the `create_workout` tool definition with `cache_control: { type: "ephemeral" }`. Tools are static and identical every request. |
| **A5** | **User message: dynamic only** — The user message contains only: task sentence, difficulty guidance, training emphasis, warm-up/cool-down selection, user context (athlete profile, PBs, weights), session notes, time budget, community workout examples, recent names. This is the ~1,000–2,000 tokens that change per request. |
| **A6** | **API call restructure** — Update `call_llm` to accept `system:` blocks with cache control headers. Add `anthropic-beta: prompt-caching-2024-07-31` header. Structure: `{ system: [...cached blocks...], messages: [{ role: "user", content: dynamic_prompt }], tools: [...cached tools...] }` |

### Token budget estimate

| Component | Current (all in user msg) | After (cached/dynamic) | Cache status |
|-----------|--------------------------|------------------------|-------------|
| Format definitions | ~1,500 tokens | System block | Cached |
| Naming / variety / rep rules | ~800 tokens | System block | Cached |
| Session-type rules (FM/Ohm/etc) | ~500–2,000 tokens | System block | Cached per type |
| Sport context file | ~500–3,000 tokens | System block | Cached per type |
| Tool schema | ~800 tokens | Tools array | Cached |
| **Subtotal: cacheable** | **~4,000–8,000 tokens** | | **90% cheaper** |
| User context + session notes | ~500–1,000 tokens | User message | Full price |
| Task sentence + time budget | ~200 tokens | User message | Full price |
| Warm-up/cool-down selection | ~100 tokens | User message | Full price |
| Community examples | ~500 tokens | User message | Full price |
| **Subtotal: dynamic** | **~1,300–1,800 tokens** | | **Full price** |

**Expected saving: ~60–80% of input tokens are cached after the first request of each session type.**

---

## Fit Check: R × A

| Req | Requirement | Status | A |
|-----|-------------|--------|---|
| R0 | Reduce per-request input token cost | Core goal | ✅ |
| R1 | Use Anthropic prompt caching | Must-have | ✅ |
| R2 | Static rules in cacheable system prompt | Must-have | ✅ |
| R3 | Session-type rules scoped per type | Must-have | ✅ |
| R4 | User context stays in user message | Must-have | ✅ |
| R5 | Tool definitions cacheable | Must-have | ✅ |
| R6 | No quality regression | Must-have | ✅ |
| R7 | FM rules intact | Must-have | ✅ |
| R8 | Works with Net::HTTP | Nice-to-have | ✅ |
| R9 | Components testable/readable | Nice-to-have | ✅ |

---

## Implementation Slices

### Slice 1: Restructure `call_llm` for system prompt + caching headers
- Add `system:` parameter to `call_llm`
- Add `anthropic-beta: prompt-caching-2024-07-31` header
- Mark system blocks and tool definitions with `cache_control`
- No prompt content changes yet — just move the existing prompt into system vs user split
- **Demo:** Generate a workout, confirm `cache_creation_input_tokens` and `cache_read_input_tokens` appear in the API response

### Slice 2: Extract universal rules into a static system prompt
- Extract format definitions, naming rules, exercise variety, rep count rules, single-exercise rules into a constant string (`UNIVERSAL_RULES`)
- Remove these from `build_prompt` and inject via system message
- **Demo:** Generate workouts of different types, confirm universal rules are cached (cache_read > 0 on second request)

### Slice 3: Extract session-type rules into modular blocks
- Create a method per session type family that returns only the relevant rules:
  - `fm_system_rules` — FM archetype, structure, validator expectations
  - `ohm_system_rules` — no warm-up/cool-down, activation/ease-down flow
  - `dynamo_system_rules` — bodyweight-only constraint
  - `event_system_rules` — station constraints, race sim, Hyrox/Deka specifics
  - `default_system_rules` — warm-up/cool-down, standard structure
- Append as second system block after universal rules
- **Demo:** Generate FM then Dynamo, confirm different cache keys (cache_creation on first of each type, cache_read on repeat)

### Slice 4: Move sport context files into system prompt
- Load the relevant `.md` file as a third system block
- Remove from user message
- **Demo:** Two back-to-back Hyrox sessions hit cache on the context file

### Slice 5: Trim `build_prompt` to dynamic-only
- `build_prompt` now returns only: task sentence, difficulty guidance, training emphasis, warm-up selection, user context, session notes, time budget, community examples, recent names
- Verify total user message is ~1,500 tokens
- Add logging: log cache hit/miss stats from API response for monitoring
- **Demo:** Full end-to-end, confirm significant token reduction in logs

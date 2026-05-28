module Program::SessionFocus
  extend ActiveSupport::Concern

  # Keywords that map free-text focus → a specific activity override.
  # The PROGRAM's primary activity is used as the default when no keyword
  # matches; this lets a Hyrox program send one session through Engine Room
  # by writing "cardio" or "engine room" in that session's focus.
  ACTIVITY_KEYWORDS = [
    [ /\b(engine\s*room|cardio\s*only|cardio\b|zone\s*2|zone\s*two)\b/i, "Engine Room" ],
    [ /\b(transformer|strength|lift(ing)?|heavy)\b/i,                    "Transformer" ]
  ].freeze

  INTENSITY_KEYWORDS = [
    [ /\b(low|easy|conversational|zone\s*2|zone\s*two|recovery)\b/i, "low" ],
    [ /\b(high|max|all[-\s]?out|near[-\s]?max|race[-\s]?day|hard\s*day|heavy\s*day)\b/i, "high" ],
    [ /\b(medium|moderate|working|threshold|tempo)\b/i, "medium" ]
  ].freeze

  module ClassMethods
    # Parses free-text session focus into { activity_name:, intensity_style:, notes: }.
    # Blank text returns nil-valued keys (no override) — the caller falls back
    # to the program's primary activity and lets the LLM pick the shape.
    def parse_session_focus(text, default_activity_name: nil)
      cleaned = text.to_s.strip
      return { activity_name: default_activity_name, intensity_style: nil, notes: nil } if cleaned.empty?

      activity = ACTIVITY_KEYWORDS.find { |pattern, _| cleaned.match?(pattern) }&.last || default_activity_name
      intensity = INTENSITY_KEYWORDS.find { |pattern, _| cleaned.match?(pattern) }&.last
      { activity_name: activity, intensity_style: intensity, notes: cleaned }
    end
  end
end

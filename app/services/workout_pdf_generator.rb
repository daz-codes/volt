class WorkoutPdfGenerator
  # Print-friendly: dark text on white background, volt green as accent
  BLACK      = "000000"
  DARK_GREY  = "27272A"
  MID_GREY   = "71717A"
  LIGHT_GREY = "E4E4E7"
  VOLT_DARK  = "5A7200"  # darkened volt green, readable on white

  def initialize(workout)
    @workout = workout
  end

  def generate
    Prawn::Document.new(page_size: "A4", margin: [ 40, 40, 50, 40 ]) do |pdf|
      pdf.font("Helvetica")
      draw_header(pdf)
      draw_meta(pdf)
      draw_structure(pdf)
      draw_footer(pdf)
    end.render
  end

  private

  def draw_header(pdf)
    pdf.fill_color BLACK
    pdf.text(@workout.name.presence || "Workout", size: 32, style: :bold)
    pdf.move_down 12
  end

  def draw_meta(pdf)
    pills = [ "#{@workout.duration_mins} min" ]
    pills.unshift(@workout.activity.name) if @workout.activity.present?

    pdf.fill_color MID_GREY
    pdf.text pills.join("   ·   "), size: 10
    pdf.move_down 8

    if @workout.structure.is_a?(Hash) && @workout.structure["goal"].present?
      pdf.fill_color DARK_GREY
      pdf.text @workout.structure["goal"], size: 10, leading: 3
      pdf.move_down 8
    end

    pdf.stroke_color LIGHT_GREY
    pdf.stroke_horizontal_rule
    pdf.move_down 14
  end

  def draw_structure(pdf)
    sections = @workout.structure.is_a?(Hash) ? Array(@workout.structure["sections"]) : []
    return if sections.empty?

    sections.each_with_index do |section, i|
      pdf.start_new_page if pdf.cursor < 120 && i > 0
      draw_section(pdf, section)
      pdf.move_down 12
    end
  end

  def draw_section(pdf, section)
    format    = section["format"].to_s
    exercises = Array(section["exercises"])

    # Section name
    pdf.fill_color VOLT_DARK
    pdf.text section["name"].to_s.upcase, size: 9, style: :bold, character_spacing: 1
    pdf.move_down 2

    # Descriptor (format / rounds / timing)
    descriptor = build_descriptor(section)
    if descriptor.present?
      pdf.fill_color MID_GREY
      pdf.text descriptor, size: 9
      pdf.move_down 4
    end

    # Exercises
    exercises.each do |ex|
      draw_exercise(pdf, ex, format)
    end

    # Section notes
    if section["notes"].present?
      pdf.move_down 2
      pdf.fill_color MID_GREY
      pdf.text section["notes"], size: 8, leading: 2
    end
  end

  def draw_exercise(pdf, ex, format)
    metric = build_exercise_metric(ex, format)

    pdf.move_down 5
    # Name + metric on one line where possible
    pdf.fill_color DARK_GREY
    name_line = "  #{ex["name"]}"
    name_line += "  —  #{metric}" if metric.present?
    pdf.text name_line, size: 10, style: :bold

    if ex["notes"].present?
      pdf.fill_color MID_GREY
      pdf.text "  #{ex["notes"]}", size: 8, leading: 1
    end
  end

  def format_rest_secs(secs)
    s = secs.to_i
    return nil if s <= 0
    s >= 60 && (s % 60).zero? ? "#{s / 60} min" : "#{s}s"
  end

  def build_descriptor(section)
    parts = []
    rounds = section["rounds"].to_i
    rest   = section["rest_secs"].to_i

    case section["format"].to_s
    when "rounds"
      parts << "#{rounds} rounds" if rounds > 0
      parts << "#{format_rest_secs(rest)} rest between rounds" if rest > 0
    when "emom"
      dur = section["duration_mins"].to_i
      parts << "Every 2 minutes · #{dur} min"
      parts << "#{format_rest_secs(rest)} rest" if rest > 0
    when "continuous_circuit"
      dur = section["duration_mins"].to_i
      ex_count = Array(section["exercises"]).size
      reps_each = dur / ex_count if ex_count > 0
      parts << "Continuous Circuit · #{dur} min · #{ex_count} exercises · #{reps_each} rounds each"
    when "tabata"
      tabata_rounds = rounds > 0 ? rounds : 8
      total_mins = ((20 + 10) * tabata_rounds / 60.0).ceil
      parts << "Tabata · 20s work / 10s rest · #{tabata_rounds} rounds (#{total_mins} min)"
    when "ladder"
      varies = section["varies"].presence || "reps"
      parts << "Ladder · #{section["start"]} down to #{section["end"]} #{varies}"
      parts << "#{section["step"]} per round" if section["step"].to_i > 1
      parts << "#{format_rest_secs(rest)} rest between rungs" if rest > 0
    when "mountain"
      varies = section["varies"].presence || "reps"
      parts << "Mountain · #{section["start"]}–#{section["peak"]}–#{section["end"]} #{varies}"
      parts << "#{format_rest_secs(rest)} rest between rungs" if rest > 0
    when "amrap"
      parts << "AMRAP · #{section["duration_mins"]} min"
    when "for_time"
      parts << "For time"
      parts << "#{rounds} rounds" if rounds > 1
    when "hundred"
      parts << "100 reps for time"
    when "straight"
      parts << "#{section["duration_mins"]} min" if section["duration_mins"].to_i > 0
    end
    parts.join(" · ")
  end

  def build_exercise_metric(ex, format)
    # Rotating EMOMs fill the full minute — no rep target
    return nil if format == "emom" && ex["reps"].to_i.zero? && ex["calories"].to_i.zero?

    parts = []
    parts << "#{ex["reps"]} reps"    if ex["reps"].to_i > 0
    parts << "#{ex["calories"]} cal" if ex["calories"].to_i > 0
    parts << "#{ex["distance_m"]}m"  if ex["distance_m"].to_i > 0
    parts << "#{ex["weight_kg"]}kg"  if ex["weight_kg"].to_f > 0
    if ex["duration_s"].to_i > 0
      s = ex["duration_s"].to_i
      parts << "#{s / 60}:#{(s % 60).to_s.rjust(2, "0")}"
    end
    parts.empty? ? nil : parts.join(" · ")
  end

  def draw_footer(pdf)
    pdf.repeat(:all) do
      pdf.bounding_box([ 0, 30 ], width: pdf.bounds.width) do
        pdf.stroke_color LIGHT_GREY
        pdf.stroke_horizontal_rule
        pdf.move_down 5
        pdf.fill_color MID_GREY
        pdf.text "Workout generated by Volt", size: 8, align: :center
      end
    end
  end
end

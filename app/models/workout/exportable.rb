module Workout::Exportable
  extend ActiveSupport::Concern

  CANVAS_WIDTH  = 1080
  CANVAS_HEIGHT = 1350
  BG_COLOR      = "#18181b"
  LIME          = "#a3e635"
  WHITE         = "#fafafa"
  LIGHT_GRAY    = "#e4e4e7"
  MID_GRAY      = "#a1a1aa"
  DIM_GRAY      = "#71717a"
  BORDER_GRAY   = "#27272a"

  def generate_share_image
    sections = export_sections
    tempfile = Tempfile.new([ "volt-share", ".png" ])

    begin
      font_bold = resolve_font

      # Pre-calculate required canvas height so nothing gets cut off.
      canvas_height = estimate_canvas_height(sections)

      y = 60
      commands = []

      # Canvas
      commands.push("-size", "#{CANVAS_WIDTH}x#{canvas_height}", "xc:#{BG_COLOR}")

      # Radial gradient overlay (lime tint, 4% opacity at top-left)
      commands.push(
        "(", "-size", "#{CANVAS_WIDTH}x#{canvas_height}",
        "radial-gradient:rgba(163,230,53,0.04)-transparent",
        "-gravity", "NorthWest",
        "-geometry", "+0+0",
        ")",
        "-composite"
      )

      # Set bold weight for all text (needed for .ttc collection fonts)
      commands.push("-font", font_bold, "-weight", "Bold")

      # Header row: activity type (left)
      if activity.present?
        commands.push("-fill", DIM_GRAY, "-pointsize", "36",
                      "-gravity", "NorthWest", "-annotate", "+56+#{y}", safe(activity.name.upcase))
      end

      # Duration (right-aligned)
      commands.push("-fill", MID_GRAY, "-pointsize", "39",
                    "-gravity", "NorthEast", "-annotate", "+56+#{y}", safe("#{duration_mins} MIN"))

      y += 52

      # Workout name (large bold)
      commands.push("-fill", WHITE, "-pointsize", workout_name_pointsize.to_s,
                    "-gravity", "NorthWest")
      name_lines = word_wrap(name.upcase, workout_name_pointsize, CANVAS_WIDTH - 112)
      name_lines.each do |line|
        commands.push("-annotate", "+56+#{y}", safe(line))
        y += (workout_name_pointsize * 1.05).to_i
      end

      y += 16

      # Lime divider
      commands.push("-fill", LIME, "-draw", "rectangle 56,#{y} #{CANVAS_WIDTH - 56},#{y + 4}")

      y += 28

      # Sections
      sections.each do |section|
        if section[:label].present?
          commands.push("-fill", LIME, "-pointsize", "50",
                        "-annotate", "+56+#{y}", safe(section[:label].upcase))
          y += 58
        end

        if section[:description].present?
          commands.push("-fill", DIM_GRAY, "-pointsize", "28",
                        "-annotate", "+56+#{y}", safe(section[:description]))
          y += 36
        end

        section[:exercises].each do |line|
          commands.push("-fill", LIGHT_GRAY, "-pointsize", "36")

          wrapped = word_wrap(line.upcase, 36, CANVAS_WIDTH - 112)
          wrapped.each do |wl|
            commands.push("-annotate", "+56+#{y}", safe(wl))
            y += 44
          end
        end

        y += 18
      end

      # Footer
      footer_y = canvas_height - 80
      commands.push("-fill", BORDER_GRAY, "-draw", "rectangle 56,#{footer_y - 20} #{CANVAS_WIDTH - 56},#{footer_y - 19}")
      commands.push("-fill", MID_GRAY, "-pointsize", "24",
                    "-gravity", "NorthEast", "-annotate", "+56+#{footer_y + 14}", safe("energise your workout"))

      commands.push(tempfile.path)

      MiniMagick.convert do |img|
        img.merge! commands
      end

      File.binread(tempfile.path)
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

  # Shared section extraction used by both share_card view and image generator
  def export_sections
    raw = structure.is_a?(Hash) ? Array(structure["sections"]) : []
    main = raw.select { |s| %w[main finisher].include?(s["category"]) }

    main.map do |section|
      fmt = section["format"].to_s
      is_ladder = %w[ladder mountain switchback].include?(fmt)
      ex_count = Array(section["exercises"]).size

      label, description = format_label_and_description(section, fmt, ex_count)

      exercises = Array(section["exercises"]).map do |ex|
        ex_name = ex["name"].to_s.gsub(/\s*\([\d.]+kg.*?\)\s*/, "").strip
        parts = []

        if ex["reps"]
          unit = ex_name.match?(/carry|sled|prowler|drag|shuttle|farmer/i) ? "m" : ""
          parts << "#{ex["reps"]}#{unit}"
        end
        parts << "#{ex["distance_m"]}m" if ex["distance_m"]
        parts << "#{ex["calories"]} cal" if ex["calories"]
        if ex["duration_s"]
          dm = ex["duration_s"] / 60
          dr = ex["duration_s"] % 60
          parts << (dm > 0 ? "#{dm}min#{dr > 0 ? " #{dr}s" : ""}" : "#{ex["duration_s"]}s")
        end
        metric = parts.join(" \u00B7 ")

        if is_ladder
          ex_name
        elsif metric.present?
          "#{metric} #{ex_name}"
        else
          ex_name
        end
      end

      { label: label, description: description, exercises: exercises }
    end
  end

  private

  # Dry-run Y calculation to determine the canvas height needed to fit all
  # content. Returns at least CANVAS_HEIGHT so short workouts still look good.
  def estimate_canvas_height(sections)
    y = 60 # top padding
    y += 52 # header row (activity + duration)

    # Workout name
    name_lines = word_wrap(name.upcase, workout_name_pointsize, CANVAS_WIDTH - 112)
    y += name_lines.size * (workout_name_pointsize * 1.05).to_i
    y += 16 # gap after name
    y += 28 # divider + gap

    sections.each do |section|
      y += 58 if section[:label].present?
      y += 36 if section[:description].present?

      section[:exercises].each do |line|
        wrapped = word_wrap(line.upcase, 36, CANVAS_WIDTH - 112)
        y += wrapped.size * 44
      end

      y += 18 # gap between sections
    end

    y += 100 # footer space

    [ y, CANVAS_HEIGHT ].max
  end

  def format_label_and_description(section, fmt, ex_count)
    rounds = section["rounds"]
    rest = section["rest_secs"]
    dur = section["duration_mins"]
    style = section["emom_style"]

    case fmt
    when "tabata"
      [ "Tabata", "8 rounds \u00B7 20s hard / 10s rest" ]
    when "emom"
      rotating = style == "rotating" || (style.blank? && ex_count > 1)
      if rotating
        cycles = dur && ex_count > 0 ? dur / ex_count : nil
        desc = cycles && cycles > 1 ? "1 min of each exercise \u00B7 #{cycles} times through" : "1 min of each exercise"
        [ "Continuous Circuit", desc ]
      elsif ex_count >= 3 && dur
        e2m_rounds = dur / 2
        desc = e2m_rounds > 1 ? "All #{ex_count} exercises every 2 min \u00B7 #{e2m_rounds} rounds" : nil
        [ "EMO2M #{dur}min", desc ]
      else
        [ "EMOM #{dur}min", rest ? "#{rest}s rest each minute" : nil ]
      end
    when "amrap"
      [ "AMRAP #{dur}min", "As many rounds as possible" ]
    when "rounds"
      label = rounds && rounds > 1 ? "#{rounds} Rounds" : nil
      desc = rest && rest > 0 ? "#{rest}s rest after each round" : nil
      [ label, desc ]
    when "for_time"
      desc = rounds && rounds > 1 ? "#{rounds} rounds \u00B7 race the clock" : "Race the clock"
      [ "For Time", desc ]
    when "ladder"
      seq = ladder_sequence(section["start"], section["end"], section["step"])
      [ "Ladder", "#{seq} reps of each exercise" ]
    when "mountain"
      seq = mountain_sequence(section["start"], section["peak"], section["end"], section["step"])
      [ "Mountain", "#{seq} reps of each exercise" ]
    when "switchback"
      down_seq, up_seq = switchback_sequences(section["start"], section["end"], section["step"])
      [ "Up & Down Ladder", "#{down_seq} cal \u00B7 #{up_seq} reps" ]
    when "hundred"
      [ "100 Reps", "For time" ]
    when "matrix"
      [ "Matrix", "Build up, strip back" ]
    else
      [ section["name"], nil ]
    end
  end

  def ladder_sequence(start_val, end_val, step)
    sv = start_val.to_i; ev = end_val.to_i; st = step.to_i.nonzero? || 1
    range = sv > ev ? sv.step(ev, -st.abs).to_a : sv.step(ev, st.abs).to_a
    range.join("\u2013")
  end

  def mountain_sequence(start_val, peak_val, end_val, step)
    sv = start_val.to_i; pk = peak_val.to_i; ev = end_val.to_i; st = step.to_i.nonzero? || 1
    up = sv.step(pk, st.abs).to_a
    down = (pk - st.abs).step(ev, -st.abs).to_a
    (up + down).join("\u2013")
  end

  def switchback_sequences(start_val, end_val, step)
    sv = start_val.to_i.nonzero? || 40
    ev = end_val.to_i.nonzero?   || 10
    st = step.to_i.nonzero?      || 10
    down = sv.step(ev, -st.abs).to_a
    up   = down.reverse
    [ down.join("\u00B7"), up.join("\u00B7") ]
  end

  def resolve_font
    # Must be a dedicated bold .ttf — .ttc collections ignore -weight Bold
    [
      "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
      "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
      "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
      "/System/Library/Fonts/Supplemental/Helvetica Neue Bold.ttf"
    ].find { |f| File.exist?(f) } || "Helvetica-Bold"
  end

  def workout_name_pointsize
    len = name.length
    if len <= 15
      100
    elsif len <= 25
      80
    elsif len <= 40
      64
    else
      50
    end
  end

  def word_wrap(text, pointsize, max_width)
    char_width = pointsize * 0.55
    max_chars = (max_width / char_width).to_i
    return [ text ] if text.length <= max_chars

    words = text.split(" ")
    lines = []
    current = ""

    words.each do |word|
      test = current.empty? ? word : "#{current} #{word}"
      if test.length > max_chars && current.present?
        lines << current
        current = word
      else
        current = test
      end
    end
    lines << current if current.present?
    lines
  end

  def safe(text)
    text.encode("UTF-8").gsub("@", "\\@").gsub("%", "%%")
  end
end

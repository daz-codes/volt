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
      y = 60

      commands = []

      # Canvas
      commands.push("-size", "#{CANVAS_WIDTH}x#{CANVAS_HEIGHT}", "xc:#{BG_COLOR}")

      # Header row: activity type (left)
      if activity.present?
        commands.push("-fill", DIM_GRAY, "-font", font_bold, "-pointsize", "36",
                      "-gravity", "NorthWest", "-annotate", "+56+#{y}", safe(activity.name.upcase))
      end

      # Duration (right-aligned)
      commands.push("-fill", MID_GRAY, "-font", font_bold, "-pointsize", "39",
                    "-gravity", "NorthEast", "-annotate", "+56+#{y}", safe("#{duration_mins} MIN"))

      y += 52

      # Workout name (large bold)
      commands.push("-fill", WHITE, "-font", font_bold, "-pointsize", workout_name_pointsize.to_s,
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
        break if y > CANVAS_HEIGHT - 120

        if section[:label].present?
          commands.push("-fill", LIME, "-font", font_bold, "-pointsize", "36",
                        "-annotate", "+56+#{y}", safe(section[:label].upcase))
          y += 44
        end

        section[:exercises].each do |line|
          break if y > CANVAS_HEIGHT - 120
          commands.push("-fill", LIGHT_GRAY, "-font", font_bold, "-pointsize", "50")

          wrapped = word_wrap(line.upcase, 50, CANVAS_WIDTH - 112)
          wrapped.each do |wl|
            commands.push("-annotate", "+56+#{y}", safe(wl))
            y += 58
          end
        end

        y += 18
      end

      # Footer
      footer_y = CANVAS_HEIGHT - 80
      commands.push("-fill", BORDER_GRAY, "-draw", "rectangle 56,#{footer_y - 20} #{CANVAS_WIDTH - 56},#{footer_y - 19}")
      commands.push("-fill", LIME, "-font", font_bold, "-pointsize", "50",
                    "-annotate", "+56+#{footer_y}", "VOLT")

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
    main = raw.reject { |s|
      s["name"].to_s.match?(/warm.?up|cool.?down|stretch|recovery|primer|activation|mobility/i)
    }

    main.map do |section|
      fmt = section["format"].to_s
      is_ladder = %w[ladder mountain].include?(fmt)

      label = case fmt
              when "tabata"   then "Tabata"
              when "emom"     then "EMOM #{section["duration_mins"]}min"
              when "amrap"    then "AMRAP #{section["duration_mins"]}min"
              when "rounds"
                rounds = section["rounds"]
                rounds && rounds > 1 ? "#{rounds} Rounds" : nil
              when "for_time" then "For Time"
              when "ladder"   then "Ladder"
              when "mountain" then "Mountain"
              when "hundred"  then "100 Reps"
              when "matrix"   then "Matrix"
              end

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
          sv = section["start"]; ev = section["end"]
          if fmt == "mountain"
            "#{ex_name} #{sv}\u2013#{section["peak"]}\u2013#{ev}"
          else
            "#{ex_name} #{sv}\u2013#{ev} (steps of #{section["step"].to_i})"
          end
        elsif metric.present?
          "#{metric} #{ex_name}"
        else
          ex_name
        end
      end

      { label: label, exercises: exercises }
    end
  end

  private

  def resolve_font
    [
      "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
      "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
      "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"
    ].find { |f| File.exist?(f) } || "Arial-Bold"
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
    text.encode("UTF-8")
  end
end

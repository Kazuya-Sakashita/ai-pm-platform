module MinutesGeneration
  class DeterministicProvider
    MODEL_NAME = "deterministic-minutes-placeholder-v1"

    def generate(meeting)
      @meeting = meeting

      {
        status: "generated",
        summary: summary,
        decisions: decisions,
        open_questions: open_questions,
        action_items: action_items,
        generated_by_model: MODEL_NAME
      }
    end

    private

    attr_reader :meeting

    def lines
      @lines ||= meeting.raw_text.to_s.lines.map(&:strip).reject(&:empty?)
    end

    def summary
      first_lines = lines.first(3).join(" ")
      first_lines.empty? ? "会議内容が入力されていません。" : first_lines[0, 500]
    end

    def decisions
      matches = matching_lines(/decision|decided|決定|決定事項|決まり|合意/i)
      matches = [summary] if matches.empty?
      matches.map { |text| { text: normalize(text) } }
    end

    def open_questions
      matching_lines(/\?|question|open question|確認|未決|論点|質問/i).map { |text| normalize(text) }
    end

    def action_items
      matching_lines(/todo|action|next|follow|対応|担当|宿題|次回|実施/i).map do |text|
        {
          text: normalize(text),
          status: "open"
        }
      end
    end

    def matching_lines(pattern)
      lines.select { |line| line.match?(pattern) }
    end

    def normalize(text)
      text.sub(/\A[-*]\s*/, "").strip
    end
  end
end

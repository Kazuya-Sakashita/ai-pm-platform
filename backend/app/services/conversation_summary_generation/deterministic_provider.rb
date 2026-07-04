module ConversationSummaryGeneration
  class DeterministicProvider
    MODEL_NAME = "deterministic-conversation-summary-v1"

    def generate(conversation_import)
      @conversation_import = conversation_import

      {
        provider: "deterministic",
        model: MODEL_NAME,
        status: "draft",
        summary: summary,
        decisions: decisions,
        open_questions: open_questions,
        action_items: action_items,
        issue_candidates: issue_candidates,
        requirement_candidates: requirement_candidates,
        risks: risks,
        participants: conversation_import.participants,
        source_quotes: source_quotes,
        confidence: 0.62
      }
    end

    private

    attr_reader :conversation_import

    def lines
      @lines ||= conversation_import.ai_source_text.to_s.lines.map(&:strip).reject(&:empty?)
    end

    def summary
      text = lines.first(4).join(" ")
      text.presence || "会話内容が入力されていません。"
    end

    def decisions
      matching_lines(/decision|decided|合意|決定|決まり|方針/i).first(5).map do |text|
        { text: normalize(text), source_quote_ids: quote_ids_for(text), confidence: 0.7 }
      end
    end

    def open_questions
      matching_lines(/\?|question|確認|未決|相談|どうする|論点/i).first(5).map { |text| normalize(text) }
    end

    def action_items
      matching_lines(/todo|action|next|follow|対応|担当|宿題|次回|実施|お願いします/i).first(5).map do |text|
        {
          text: normalize(text),
          status: "open",
          source_quote_ids: quote_ids_for(text),
          confidence: 0.66
        }
      end
    end

    def issue_candidates
      seed = (decisions + action_items).first
      return [] unless seed

      text = seed.fetch(:text)
      [
        {
          title: text.first(80),
          body: "Discord DMの会話から抽出した対応候補です。\n\n背景:\n#{summary.first(400)}",
          labels: ["conversation-import", "needs-review"],
          priority: "P1",
          source_quote_ids: seed.fetch(:source_quote_ids, []),
          confidence: 0.58
        }
      ]
    end

    def requirement_candidates
      [
        {
          title: "DM会話整理結果のレビュー",
          requirement: summary.first(500),
          acceptance_criteria: ["人間が整理結果を確認し、Issue化してよい内容だけを承認できる"],
          source_quote_ids: source_quotes.first(2).map { |quote| quote.fetch(:id) },
          confidence: 0.56
        }
      ]
    end

    def risks
      risk_lines = matching_lines(/risk|懸念|リスク|秘密|個人情報|同意|認証|token|password/i).first(5)
      risk_lines.map do |text|
        {
          text: normalize(text),
          severity: "medium",
          mitigation: "AI整理前にredactionとレビューを実施する",
          source_quote_ids: quote_ids_for(text),
          confidence: 0.6
        }
      end
    end

    def source_quotes
      @source_quotes ||= lines.first(5).each_with_index.map do |line, index|
        {
          id: "q#{index + 1}",
          quote: line.first(500)
        }
      end
    end

    def quote_ids_for(text)
      source_quotes.select { |quote| quote.fetch(:quote) == text.first(500) }.map { |quote| quote.fetch(:id) }
    end

    def matching_lines(pattern)
      lines.select { |line| line.match?(pattern) }
    end

    def normalize(text)
      text.sub(/\A[-*]\s*/, "").strip
    end
  end
end

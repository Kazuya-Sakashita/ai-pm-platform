module RequirementGeneration
  class DeterministicProvider
    MODEL_NAME = "deterministic-requirements-placeholder-v1"

    def generate(minutes)
      @minutes = minutes

      {
        status: "generated",
        background: background,
        goal: goal,
        user_stories: user_stories,
        functional_requirements: functional_requirements,
        non_functional_requirements: non_functional_requirements,
        acceptance_criteria: acceptance_criteria,
        out_of_scope: out_of_scope,
        open_questions: open_questions,
        risks: risks,
        generated_by_model: MODEL_NAME
      }
    end

    private

    attr_reader :minutes

    def background
      "議事録サマリー: #{minutes.summary}"
    end

    def goal
      first_decision = decisions.first
      return "会議で合意した内容を、実装可能な要件定義ドラフトへ変換する。" unless first_decision

      "会議で合意した「#{first_decision}」を実装可能な成果物にする。"
    end

    def user_stories
      source_items.first(3).map do |item|
        "プロジェクトメンバーとして、#{item} を実現し、チームがレビューゲートを通過して実装へ進めるようにしたい。"
      end
    end

    def functional_requirements
      items = source_items
      items = [minutes.summary] if items.empty?

      items.map.with_index(1) { |item, index| "FR-#{index.to_s.rjust(3, '0')}: #{item}" }
    end

    def non_functional_requirements
      [
        "レビュー結果と生成元Minutesを監査できること。",
        "Issue生成とOpenAPI設計に再利用できる構造化データで保存すること。"
      ]
    end

    def acceptance_criteria
      functional_requirements.map do |requirement|
        "承認済み議事録から要件定義を生成したとき、#{requirement.sub(/\AFR-\d+:\s*/, '')} が編集可能な要件項目として表現されている。"
      end
    end

    def out_of_scope
      [
        "人間レビューなしの完全自動承認。",
        "GitHub Issueへの自動公開。"
      ]
    end

    def open_questions
      Array(minutes.open_questions).map(&:to_s).map(&:strip).reject(&:empty?)
    end

    def risks
      values = ["AI生成内容は人間レビュー前提であり、意思決定の欠落や誤解釈が残る可能性がある。"]
      values << "未決事項が残っているため、Issue化前に確認が必要。" if open_questions.any?
      values
    end

    def source_items
      (decisions + action_items).uniq
    end

    def decisions
      Array(minutes.decisions).filter_map { |item| normalize_item(item) }
    end

    def action_items
      Array(minutes.action_items).filter_map { |item| normalize_item(item) }
    end

    def normalize_item(item)
      value = item.is_a?(Hash) ? item["text"] || item[:text] : item
      value.to_s.strip.presence
    end
  end
end

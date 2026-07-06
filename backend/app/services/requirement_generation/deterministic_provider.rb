module RequirementGeneration
  class DeterministicProvider
    MODEL_NAME = "deterministic-requirements-placeholder-v1"

    def generate(minutes)
      @minutes = minutes
      @source_text = nil

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
      values = [
        "レビュー結果と生成元Minutesを監査できること。",
        "Issue生成とOpenAPI設計に再利用できる構造化データで保存すること。"
      ]
      values.concat(security_non_functional_requirements)
      values.concat(operations_non_functional_requirements)
      values.uniq
    end

    def acceptance_criteria
      functional_requirements.map do |requirement|
        "承認済み議事録から要件定義を生成したとき、#{requirement.sub(/\AFR-\d+:\s*/, '')} が編集可能な要件項目として表現されている。"
      end
    end

    def out_of_scope
      values = [
        "人間レビューなしの完全自動承認。",
        "GitHub Issueへの自動公開。"
      ]
      values.concat(detected_out_of_scope)
      values.uniq
    end

    def open_questions
      Array(minutes.open_questions).map(&:to_s).map(&:strip).reject(&:empty?)
    end

    def risks
      values = ["AI生成内容は人間レビュー前提であり、意思決定の欠落や誤解釈が残る可能性がある。"]
      values << "未決事項が残っているため、Issue化前に確認が必要。" if open_questions.any?
      values
    end

    def security_non_functional_requirements
      return [] unless includes_any?("機微情報", "PII", "個人情報", "メールアドレス", "API key", "secret")

      [
        "機微情報、PII、secret候補はRequirement本文へ直接残さず、生成前後にsecret scanとPIIマスキングを適用すること。",
        "Requirement閲覧、編集、承認は権限境界を設け、監査ログで追跡できること。"
      ]
    end

    def operations_non_functional_requirements
      values = []
      if includes_any?("CI", "品質低下", "警告")
        values << "CIでRequirement生成品質低下を検知し、初期MVPでは警告としてレビュー担当へ提示すること。"
      end

      if includes_any?("差分", "短時間", "レビュー担当", "UX")
        values << "レビュー担当がRequirement差分、未決事項、リスクを短時間で確認できるUXにすること。"
      end

      if includes_any?("OpenAPI", "乖離")
        values << "Requirement、OpenAPI、実装の乖離をレビューで監査できること。"
      end

      values
    end

    def detected_out_of_scope
      values = []
      if includes_any?("SSO") && includes_any?("MVP外", "非スコープ")
        values << "SSO実装はMVP外。"
      end

      if includes_any?("Backend", "Frontend", "実装") && includes_any?("次工程", "今回の議論", "Requirement品質まで")
        values << "Backend/Frontend実装は今回のRequirement生成評価の非スコープ。"
      end

      if includes_any?("未定", "未設定") && includes_any?("利用者", "入力データ", "成功指標", "予算")
        values << "未設定の利用者、入力データ、成功指標、予算を推測で確定すること。"
      end

      if includes_any?("自動採点") && includes_any?("警告扱い")
        values << "初期MVPでの自動採点による完全自動ブロック。"
      end

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

    def includes_any?(*terms)
      terms.any? { |term| source_text.include?(term) }
    end

    def source_text
      @source_text ||= [
        minutes.summary,
        decisions,
        open_questions,
        action_items
      ].flatten.compact.join("\n")
    end
  end
end

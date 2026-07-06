module IssueDraftGeneration
  class DeterministicProvider
    def generate(requirement)
      {
        status: "draft",
        title: title(requirement),
        body: body(requirement),
        acceptance_criteria: Array(requirement.acceptance_criteria),
        labels: labels(requirement)
      }
    end

    private

    def title(requirement)
      source = requirement.goal.presence ||
               Array(requirement.functional_requirements).first ||
               "承認済み要件を実装する"
      normalized = source.to_s.gsub(/\AFR-\d+:\s*/, "").strip
      normalized = "承認済み要件を実装する" if normalized.empty?
      normalized[0, 120]
    end

    def body(requirement)
      [
        "## 背景",
        requirement.background,
        "",
        "## 目的",
        requirement.goal,
        "",
        list_section("ユーザーストーリー", requirement.user_stories),
        list_section("機能要件", requirement.functional_requirements),
        list_section("非機能要件", requirement.non_functional_requirements),
        list_section("完了条件", requirement.acceptance_criteria),
        list_section("スコープ外", requirement.out_of_scope),
        list_section("未決事項", requirement.open_questions),
        list_section("リスク", requirement.risks),
        "## レビューゲート",
        "- 要件ステータス: #{requirement.status}",
        "- 生成元要件ID: #{requirement.id}",
        "- 実装前に人間レビューが必要です。"
      ].flatten.join("\n").strip
    end

    def list_section(title, values)
      items = Array(values).map(&:to_s).map(&:strip).reject(&:empty?)
      lines = ["## #{title}"]
      lines += items.any? ? items.map { |item| "- #{item}" } : ["- 未設定"]
      lines << ""
      lines
    end

    def labels(requirement)
      labels = %w[ai-generated requirement needs-review]
      labels << "has-open-questions" if Array(requirement.open_questions).any?
      labels.uniq
    end
  end
end

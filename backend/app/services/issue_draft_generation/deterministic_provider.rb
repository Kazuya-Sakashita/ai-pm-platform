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
               "Implement approved requirement"
      normalized = source.to_s.gsub(/\AFR-\d+:\s*/, "").strip
      normalized = "Implement approved requirement" if normalized.empty?
      normalized[0, 120]
    end

    def body(requirement)
      [
        "## Background",
        requirement.background,
        "",
        "## Goal",
        requirement.goal,
        "",
        list_section("User Stories", requirement.user_stories),
        list_section("Functional Requirements", requirement.functional_requirements),
        list_section("Non-Functional Requirements", requirement.non_functional_requirements),
        list_section("Acceptance Criteria", requirement.acceptance_criteria),
        list_section("Out of Scope", requirement.out_of_scope),
        list_section("Open Questions", requirement.open_questions),
        list_section("Risks", requirement.risks),
        "## Review Gate",
        "- Requirement status: #{requirement.status}",
        "- Generated from Requirement ID: #{requirement.id}",
        "- Human review is required before implementation."
      ].flatten.join("\n").strip
    end

    def list_section(title, values)
      items = Array(values).map(&:to_s).map(&:strip).reject(&:empty?)
      lines = ["## #{title}"]
      lines += items.any? ? items.map { |item| "- #{item}" } : ["- None"]
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

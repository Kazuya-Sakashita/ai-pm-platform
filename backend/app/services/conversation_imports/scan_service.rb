module ConversationImports
  class ScanService
    Result = Struct.new(:valid, :conversation_import, :safety_flags, :blocked_reasons, :redaction_suggestions, :next_action, keyword_init: true)

    def initialize(conversation_import)
      @conversation_import = conversation_import
    end

    def call
      scan_result = SensitiveContentScanner.scan(conversation_import.ai_source_text)
      safety_flags = consent_flags + scan_result.findings.map { |finding| safety_flag_for(finding) }
      blocked_reasons = blocked_reasons_for(safety_flags)
      valid = blocked_reasons.empty?

      conversation_import.update!(
        status: valid ? "ready_for_ai" : "blocked",
        safety_flags: safety_flags,
        blocked_reasons: blocked_reasons,
        last_scanned_at: Time.current
      )

      AuditLog.record!(
        project: conversation_import.project,
        action: "conversation_import.scanned",
        target: conversation_import,
        metadata: {
          valid: valid,
          safety_flag_count: safety_flags.size,
          blocked_reasons: blocked_reasons
        }
      )

      Result.new(
        valid: valid,
        conversation_import: conversation_import,
        safety_flags: safety_flags,
        blocked_reasons: blocked_reasons,
        redaction_suggestions: redaction_suggestions_for(safety_flags),
        next_action: valid ? "generate_summary" : "edit_and_rescan"
      )
    end

    private

    attr_reader :conversation_import

    def consent_flags
      return [] if conversation_import.consent_confirmed?

      [
        {
          type: "consent_missing",
          severity: "high",
          action: "blocked",
          location_hint: "同意確認",
          message: "DM取り込み前に、参加者の同意または取り込み権限を確認してください。"
        }
      ]
    end

    def safety_flag_for(finding)
      {
        type: flag_type_for(finding.type),
        severity: "high",
        action: "blocked",
        location_hint: "本文",
        message: "秘密情報または認証情報の可能性があります。AI整理前に伏字化してください。"
      }
    end

    def flag_type_for(finding_type)
      return "credential" if finding_type.match?(/token|key|authorization|password/i)

      "secret"
    end

    def blocked_reasons_for(safety_flags)
      safety_flags.map { |flag| "#{flag.fetch(:type)}_blocked" }.uniq
    end

    def redaction_suggestions_for(safety_flags)
      safety_flags.filter_map do |flag|
        next if flag.fetch(:type) == "consent_missing"

        {
          location_hint: flag.fetch(:location_hint),
          reason: flag.fetch(:message),
          suggested_replacement: "[REDACTED]"
        }
      end
    end
  end
end

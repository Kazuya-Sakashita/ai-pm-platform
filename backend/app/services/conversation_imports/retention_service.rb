module ConversationImports
  class RetentionService
    DEFAULT_BATCH_SIZE = 100

    Result = Struct.new(:raw_text_purged_count, :anonymized_count, keyword_init: true)

    def initialize(now: Time.current, batch_size: DEFAULT_BATCH_SIZE)
      @now = now
      @batch_size = batch_size
    end

    def call
      Result.new(
        raw_text_purged_count: purge_expired_raw_text!,
        anonymized_count: anonymize_expired_imports!
      )
    end

    def anonymize!(conversation_import, reason: "manual_delete", actor_id: "system")
      return conversation_import if conversation_import.anonymized_at?

      summary_draft_count = conversation_import.conversation_summary_drafts.count
      conversation_import.anonymize!(anonymized_at: now)
      AuditLog.record!(
        project: conversation_import.project,
        action: "conversation_import.anonymized",
        target: conversation_import,
        actor_id: actor_id,
        metadata: {
          reason: reason,
          summary_draft_count: summary_draft_count,
          raw_text_purged: true
        }
      )
      conversation_import
    end

    private

    attr_reader :now, :batch_size

    def purge_expired_raw_text!
      count = 0
      ConversationImport
        .where(raw_text_purged_at: nil)
        .where.not(raw_text_retention_expires_at: nil)
        .where(raw_text_retention_expires_at: ..now)
        .limit(batch_size)
        .find_each do |conversation_import|
          conversation_import.purge_raw_text!(purged_at: now)
          AuditLog.record!(
            project: conversation_import.project,
            action: "conversation_import.raw_text_purged",
            target: conversation_import,
            metadata: {
              reason: "raw_text_retention_expired",
              raw_text_retention_expires_at: conversation_import.raw_text_retention_expires_at&.iso8601
            }
          )
          count += 1
        end
      count
    end

    def anonymize_expired_imports!
      count = 0
      ConversationImport
        .where(anonymized_at: nil)
        .where.not(retention_expires_at: nil)
        .where(retention_expires_at: ..now)
        .limit(batch_size)
        .find_each do |conversation_import|
          anonymize!(conversation_import, reason: "retention_expired")
          count += 1
        end
      count
    end
  end
end

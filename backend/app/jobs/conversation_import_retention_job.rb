class ConversationImportRetentionJob < ApplicationJob
  queue_as :default

  def perform(batch_size = ConversationImports::RetentionService::DEFAULT_BATCH_SIZE)
    result = ConversationImports::RetentionService.new(batch_size: batch_size.to_i).call
    Rails.logger.info(
      {
        event: "conversation_import_retention.completed",
        raw_text_purged_count: result.raw_text_purged_count,
        anonymized_count: result.anonymized_count
      }.to_json
    )
    result
  end
end

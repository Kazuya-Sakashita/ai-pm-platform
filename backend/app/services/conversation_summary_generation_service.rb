class ConversationSummaryGenerationService
  def initialize(conversation_import, provider: ConversationSummaryGeneration::DeterministicProvider.new)
    @conversation_import = conversation_import
    @provider = provider
  end

  def call
    ensure_ready_for_ai!

    conversation_import.update!(status: "summarizing")
    attributes = provider.generate(conversation_import)
    draft = conversation_import.conversation_summary_drafts.create!(attributes)
    conversation_import.update!(status: "summary_draft")
    draft
  end

  private

  attr_reader :conversation_import, :provider

  def ensure_ready_for_ai!
    return if conversation_import.status.in?(%w[ready_for_ai summary_draft])

    raise ConversationSummaryGeneration::ProviderError.new(
      code: "conversation_import_not_ready_for_ai",
      message: "Conversation import must be scanned and clear before summary generation.",
      safe_detail: "会話ログはAI整理前に同意確認と安全チェックを完了してください。"
    )
  end
end

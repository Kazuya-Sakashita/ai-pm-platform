require "rails_helper"

RSpec.describe ConversationSummaryGenerationService do
  it "persists a conversation summary draft from an injected provider" do
    conversation_import = create(:conversation_import, status: "ready_for_ai")
    provider = instance_double(
      "ConversationSummaryProvider",
      generate: {
        provider: "test",
        model: "provider-test",
        status: "draft",
        summary: "Provider summary",
        decisions: [{ text: "Provider decision", confidence: 0.8 }],
        open_questions: ["Provider question"],
        action_items: [{ text: "Provider action", status: "open", confidence: 0.8 }],
        issue_candidates: [],
        requirement_candidates: [],
        risks: [],
        participants: conversation_import.participants,
        source_quotes: [{ id: "q1", quote: "Provider quote" }],
        confidence: 0.82
      }
    )

    draft = described_class.new(conversation_import, provider: provider).call

    expect(draft.summary).to eq("Provider summary")
    expect(draft.provider).to eq("test")
    expect(draft.model).to eq("provider-test")
    expect(conversation_import.reload.status).to eq("summary_draft")
  end

  it "does not build the OpenAI provider before the ready-for-AI gate passes" do
    conversation_import = create(:conversation_import, status: "blocked")

    with_env("CONVERSATION_SUMMARY_GENERATION_PROVIDER" => "openai", "OPENAI_API_KEY" => "test-key") do
      expect(ConversationSummaryGeneration::OpenaiProvider).not_to receive(:new)

      expect do
        described_class.new(conversation_import).call
      end.to raise_error(ConversationSummaryGeneration::ProviderError) { |error|
        expect(error.code).to eq("conversation_import_not_ready_for_ai")
      }
    end
  end

  it "restores ready_for_ai status when the provider fails after summarizing starts" do
    conversation_import = create(:conversation_import, status: "ready_for_ai")
    provider = instance_double("ConversationSummaryProvider")
    allow(provider).to receive(:generate).and_raise(
      ConversationSummaryGeneration::ProviderError.new(
        code: "rate_limit_exceeded",
        message: "OpenAI request failed with HTTP 429",
        safe_detail: "OpenAI request was rate limited. Retry after the provider limit resets.",
        http_status: :too_many_requests,
        request_id: "req_rate"
      )
    )

    expect do
      described_class.new(conversation_import, provider: provider).call
    end.to raise_error(ConversationSummaryGeneration::ProviderError)

    expect(conversation_import.reload.status).to eq("ready_for_ai")
  end

  def with_env(values)
    originals = values.keys.to_h { |key| [key, ENV[key]] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    originals.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end

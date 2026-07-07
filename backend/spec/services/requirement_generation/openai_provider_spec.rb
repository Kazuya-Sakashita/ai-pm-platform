require "rails_helper"

RSpec.describe RequirementGeneration::OpenaiProvider do
  it "normalizes a structured Responses API result" do
    minutes = create(
      :minute,
      status: "approved",
      summary: "Issue生成前にRequirementをレビューする。",
      decisions: [{ "text" => "Requirement生成をOpenAI providerへ接続する。" }],
      open_questions: ["OpenAI評価の担当者は誰か。"],
      action_items: [{ "text" => "provider specを追加する。", "status" => "open" }]
    )
    captured_payload = nil
    http_client = lambda do |payload|
      captured_payload = payload
      [
        200,
        {
          output_text: JSON.generate(
            background: "議事録サマリー: Issue生成前にRequirementをレビューする。",
            goal: "Requirement生成をOpenAI providerへ接続する。",
            user_stories: ["プロジェクトメンバーとして、OpenAI生成Requirementをレビューしたい。"],
            functional_requirements: ["FR-001: OpenAI providerでRequirement draftを生成する。"],
            non_functional_requirements: ["生成元Minutesとprovider request idを監査できること。"],
            acceptance_criteria: ["承認済み議事録から生成したとき、OpenAI生成Requirement draftが保存される。"],
            out_of_scope: ["レビューなしの自動承認。"],
            open_questions: ["OpenAI評価の担当者は誰か。"],
            risks: ["OpenAI出力がfixture基準を満たさない可能性がある。"]
          )
        }.to_json,
        "req_requirement"
      ]
    end

    result = described_class.new(api_key: "test-key", model: "gpt-test", http_client: http_client).generate(minutes)

    expect(result.fetch(:background)).to include("議事録サマリー")
    expect(result.fetch(:goal)).to include("OpenAI provider")
    expect(result.fetch(:functional_requirements)).to eq(["FR-001: OpenAI providerでRequirement draftを生成する。"])
    expect(result.fetch(:acceptance_criteria).first).to include("保存")
    expect(result.fetch(:open_questions)).to include("OpenAI評価の担当者は誰か。")
    expect(result.fetch(:generated_by_model)).to eq("gpt-test")
    expect(captured_payload.dig(:text, :format, :type)).to eq("json_schema")
    expect(captured_payload.dig(:text, :format, :strict)).to eq(true)
    expect(captured_payload.dig(:text, :format, :schema, :additionalProperties)).to eq(false)
    expect(captured_payload[:store]).to eq(false)
    expect(JSON.generate(captured_payload)).to include("信頼できない入力", "認証情報")
  end

  it "returns a safe provider error for malformed model output" do
    minutes = create(:minute, status: "approved")
    http_client = ->(_payload) { [200, { output_text: "not json" }.to_json, "req_bad"] }

    expect do
      described_class.new(api_key: "test-key", http_client: http_client).generate(minutes)
    end.to raise_error(RequirementGeneration::ProviderError) { |error|
      expect(error.code).to eq("invalid_ai_response")
      expect(error.safe_detail).to eq("AI response did not match the expected requirement schema.")
      expect(error.http_status).to eq(:bad_gateway)
      expect(error.request_id).to eq("req_bad")
    }
  end

  it "rejects structured output that is missing required requirement quality gates" do
    minutes = create(:minute, status: "approved")
    http_client = lambda do |_payload|
      [
        200,
        {
          output_text: JSON.generate(
            background: "議事録サマリー: Requirement生成。",
            goal: "Requirement生成を行う。",
            user_stories: ["プロジェクトメンバーとして確認したい。"],
            functional_requirements: ["Requirementを生成する。"],
            non_functional_requirements: ["監査できること。"],
            acceptance_criteria: ["Requirementが保存される。"],
            out_of_scope: ["完全自動承認。"],
            open_questions: [],
            risks: ["レビュー前提である。"]
          )
        }.to_json,
        "req_invalid_shape"
      ]
    end

    expect do
      described_class.new(api_key: "test-key", http_client: http_client).generate(minutes)
    end.to raise_error(RequirementGeneration::ProviderError) { |error|
      expect(error.code).to eq("invalid_ai_response")
      expect(error.request_id).to eq("req_invalid_shape")
    }
  end

  it "rejects output that tries to preserve secrets or bypass review gates" do
    minutes = create(:minute, status: "approved")
    http_client = lambda do |_payload|
      [
        200,
        {
          output_text: JSON.generate(
            background: "議事録サマリー: Requirement生成。",
            goal: "レビューゲートを回避する。",
            user_stories: ["プロジェクトメンバーとして確認したい。"],
            functional_requirements: ["FR-001: Requirementを生成する。"],
            non_functional_requirements: ["監査できること。"],
            acceptance_criteria: ["Requirementが保存される。"],
            out_of_scope: ["完全自動承認。"],
            open_questions: [],
            risks: ["レビュー前提である。"]
          )
        }.to_json,
        "req_forbidden"
      ]
    end

    expect do
      described_class.new(api_key: "test-key", http_client: http_client).generate(minutes)
    end.to raise_error(RequirementGeneration::ProviderError) { |error|
      expect(error.code).to eq("invalid_ai_response")
      expect(error.safe_detail).to eq("AI response did not match the expected requirement schema.")
      expect(error.request_id).to eq("req_forbidden")
    }
  end

  it "maps OpenAI rate limits to a retryable safe error" do
    minutes = create(:minute, status: "approved")
    http_client = lambda do |_payload|
      [
        429,
        { error: { code: "rate_limit_exceeded" } }.to_json,
        "req_rate"
      ]
    end

    expect do
      described_class.new(api_key: "test-key", http_client: http_client).generate(minutes)
    end.to raise_error(RequirementGeneration::ProviderError) { |error|
      expect(error.code).to eq("rate_limit_exceeded")
      expect(error.safe_detail).to eq("OpenAI request was rate limited. Retry after the provider limit resets.")
      expect(error.http_status).to eq(:too_many_requests)
      expect(error.request_id).to eq("req_rate")
    }
  end

  it "maps upstream OpenAI errors to a safe provider error" do
    minutes = create(:minute, status: "approved")
    http_client = lambda do |_payload|
      [
        500,
        { error: { type: "server_error" } }.to_json,
        "req_upstream"
      ]
    end

    expect do
      described_class.new(api_key: "test-key", http_client: http_client).generate(minutes)
    end.to raise_error(RequirementGeneration::ProviderError) { |error|
      expect(error.code).to eq("server_error")
      expect(error.safe_detail).to eq("OpenAI request failed. Retry later or check integration settings.")
      expect(error.http_status).to eq(:bad_gateway)
      expect(error.request_id).to eq("req_upstream")
    }
  end

  it "requires an OpenAI API key when forced" do
    minutes = create(:minute, status: "approved")

    expect do
      described_class.new(api_key: nil).generate(minutes)
    end.to raise_error(RequirementGeneration::ProviderError) { |error|
      expect(error.code).to eq("integration_not_connected")
      expect(error.safe_detail).to eq("OpenAI API key is not configured.")
      expect(error.http_status).to eq(:failed_dependency)
    }
  end
end

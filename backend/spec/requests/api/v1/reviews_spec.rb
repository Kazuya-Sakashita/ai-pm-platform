require "rails_helper"

RSpec.describe "API V1 Reviews", type: :request do
  describe "POST /api/v1/reviews" do
    it "creates a review" do
      meeting = create(:meeting)
      authorize_project(meeting.project, actor_id: "reviewer-actor", role: "reviewer")

      post "/api/v1/reviews", params: {
        target_type: "meeting",
        target_id: meeting.id,
        reviewer_role: "Tech Lead",
        framework: ["G-STACK"],
        positives: ["Traceable"],
        improvements: ["Add tests"],
        priority: ["P0"],
        next_actions: ["Write request spec"],
        issue_numbers: ["ISSUE-015"]
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("open")

      event = ReviewStateEvent.find_by!(review_id: body.dig("data", "id"), event_type: "review_requested")
      expect(event).to have_attributes(
        project_id: meeting.project.id,
        actor_id: "reviewer-actor",
        from_status: nil,
        to_status: "open"
      )
    end

    it "secretや個人情報を含むレビュー本文を保存しない" do
      meeting = create(:meeting)
      authorize_project(meeting.project, actor_id: "reviewer-actor", role: "reviewer")

      post "/api/v1/reviews", params: {
        target_type: "meeting",
        target_id: meeting.id,
        reviewer_role: "Security Engineer",
        framework: ["STRIDE"],
        positives: ["監査対象が明確"],
        improvements: ["api_key=abcdefghijklmnopqrstuvwxyz123456 を削除する"],
        priority: ["P0"],
        next_actions: ["伏字化して再提出する"],
        issue_numbers: ["ISSUE-054"]
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("sensitive_content_detected")
      expect(body.to_s).not_to include("abcdefghijklmnopqrstuvwxyz123456")
      expect(Review.where(target_type: "meeting", target_id: meeting.id)).to be_empty
    end

    it "stores a minutes review result" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")

      post "/api/v1/reviews", params: {
        target_type: "minutes",
        target_id: minute.id,
        reviewer_role: "QA",
        framework: ["ISO25010"],
        positives: ["Minutes are structured"],
        improvements: ["Clarify owners"],
        priority: ["P1"],
        next_actions: ["Assign action item owners"],
        issue_numbers: ["ISSUE-002"]
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body).dig("data", "target_type")).to eq("minutes")
    end

    it "stores a conversation summary draft review result" do
      draft = create(:conversation_summary_draft)
      authorize_project(draft.conversation_import.project, actor_id: "reviewer-actor", role: "reviewer")

      post "/api/v1/reviews", params: {
        target_type: "conversation_summary_draft",
        target_id: draft.id,
        reviewer_role: "Product Manager",
        framework: ["G-STACK", "HEART"],
        positives: ["DM整理ドラフトを編集済み"],
        improvements: ["承認前にレビュー状態を確認する"],
        priority: ["P1"],
        next_actions: ["未解決レビューを解決してから承認する"],
        issue_numbers: ["ISSUE-037"]
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body.dig("data", "target_type")).to eq("conversation_summary_draft")
      expect(body.dig("data", "target_id")).to eq(draft.id)
    end

    it "rejects reviews for project targets by non-members" do
      minute = create(:minute)

      post "/api/v1/reviews", params: {
        target_type: "minutes",
        target_id: minute.id,
        reviewer_role: "QA",
        framework: ["ISO25010"],
        positives: ["Structured"],
        improvements: ["Clarify owners"],
        priority: ["P1"],
        next_actions: ["Assign owners"],
        issue_numbers: ["ISSUE-002"]
      }, headers: auth_headers("outsider")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end

  describe "POST /api/v1/reviews/:id/resolve-action" do
    it "marks a review as resolved" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")
      review = create(:review, target_type: "minutes", target_id: minute.id)

      post "/api/v1/reviews/#{review.id}/resolve-action", params: {
        resolution_note: "Request specs added."
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "status")).to eq("resolved")
      event = review.review_state_events.find_by!(event_type: "review_resolved")
      expect(event.actor_id).to eq("reviewer-actor")
      expect(event.from_status).to eq("open")
      expect(event.to_status).to eq("resolved")
      expect(event.reason_summary).to eq("Request specs added.")
    end

    it "rejects review resolution by editors" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "editor-actor", role: "editor")
      review = create(:review, target_type: "minutes", target_id: minute.id)

      post "/api/v1/reviews/#{review.id}/resolve-action", params: {
        resolution_note: "Request specs added."
      }, headers: auth_headers("editor-actor")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end

    it "secretを含む解決メモを保存しない" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")
      review = create(:review, target_type: "minutes", target_id: minute.id)

      post "/api/v1/reviews/#{review.id}/resolve-action", params: {
        resolution_note: "password=hunter2 を確認しました。"
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("sensitive_content_detected")
      expect(review.reload.status).to eq("open")
      expect(review.resolution_note).to be_nil
      expect(review.review_state_events).to be_empty
    end
  end

  describe "POST /api/v1/reviews/:id/accept-risk" do
    it "認証済みactorをリスク受容者として記録し、状態遷移イベントを保存する" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")
      review = create(:review, target_type: "minutes", target_id: minute.id, status: "action_required")

      post "/api/v1/reviews/#{review.id}/accept-risk", params: {
        reason: "MVP検証のため期限付きで受容する",
        residual_risk: "リリース前に再評価する",
        approved_by: "spoofed-actor",
        expires_at: 1.week.from_now.iso8601,
        linked_issue_number: "ISSUE-054"
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("accepted_risk")
      expect(body.dig("data", "accepted_risk", "approved_by")).to eq("reviewer-actor")
      expect(body.dig("data", "accepted_risk", "approved_by")).not_to eq("spoofed-actor")

      event = review.review_state_events.find_by!(event_type: "review_risk_accepted")
      expect(event).to have_attributes(
        actor_id: "reviewer-actor",
        from_status: "action_required",
        to_status: "accepted_risk",
        reason_summary: "MVP検証のため期限付きで受容する"
      )
      expect(event.issue_numbers).to eq(["ISSUE-054"])
    end

    it "secretを含むリスク受容理由を保存しない" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")
      review = create(:review, target_type: "minutes", target_id: minute.id, status: "action_required")

      post "/api/v1/reviews/#{review.id}/accept-risk", params: {
        reason: "api_key=abcdefghijklmnopqrstuvwxyz123456 を一時利用する",
        residual_risk: "後で削除する",
        expires_at: 1.week.from_now.iso8601,
        linked_issue_number: "ISSUE-054"
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("sensitive_content_detected")
      expect(review.reload.status).to eq("action_required")
      expect(review.accepted_risk).to be_nil
      expect(review.review_state_events).to be_empty
    end
  end

  describe "POST /api/v1/reviews/:id/reopen" do
    it "解決済みレビューを再オープンし、状態遷移イベントを保存する" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")
      review = create(:review, target_type: "minutes", target_id: minute.id, status: "resolved", resolution_note: "対応済み")

      post "/api/v1/reviews/#{review.id}/reopen", params: {
        reason_summary: "追加確認が必要",
        issue_numbers: ["ISSUE-054"]
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "status")).to eq("open")
      event = review.review_state_events.find_by!(event_type: "review_reopened")
      expect(event).to have_attributes(
        actor_id: "reviewer-actor",
        from_status: "resolved",
        to_status: "open",
        reason_summary: "追加確認が必要"
      )
    end
  end

  describe "GET /api/v1/reviews/:id/events" do
    it "レビュー状態遷移イベントを時系列で返す" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "viewer-actor", role: "viewer")
      review = create(:review, target_type: "minutes", target_id: minute.id)
      old_event = create_review_state_event(review, minute.meeting.project, "review_requested", nil, "open", 2.hours.ago)
      new_event = create_review_state_event(review, minute.meeting.project, "review_resolved", "open", "resolved", 1.hour.ago)

      get "/api/v1/reviews/#{review.id}/events", headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).fetch("data").map { |item| item.fetch("id") }
      expect(ids).to eq([new_event.id, old_event.id])
    end
  end

  describe "GET /api/v1/reviews" do
    it "lists reviews only for the requested project" do
      visible_minute = create(:minute)
      hidden_minute = create(:minute)
      authorize_project(visible_minute.meeting.project, actor_id: "viewer-actor", role: "viewer")
      visible_review = create(:review, target_type: "minutes", target_id: visible_minute.id)
      create(:review, target_type: "minutes", target_id: hidden_minute.id)

      get "/api/v1/reviews", params: { project_id: visible_minute.meeting.project.id }, headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).fetch("data").map { |item| item.fetch("id") }
      expect(ids).to eq([visible_review.id])
    end

    it "lists conversation summary draft reviews by target" do
      draft = create(:conversation_summary_draft)
      authorize_project(draft.conversation_import.project, actor_id: "viewer-actor", role: "viewer")
      review = create(:review, target_type: "conversation_summary_draft", target_id: draft.id)

      get "/api/v1/reviews", params: {
        target_type: "conversation_summary_draft",
        target_id: draft.id
      }, headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).fetch("data").map { |item| item.fetch("id") }
      expect(ids).to eq([review.id])
    end
  end

  def create_review_state_event(review, project, event_type, from_status, to_status, occurred_at)
    ReviewStateEvent.create!(
      review: review,
      project: project,
      target_type: review.target_type,
      target_id: review.target_id,
      event_type: event_type,
      from_status: from_status,
      to_status: to_status,
      actor_id: "reviewer-actor",
      issue_numbers: review.issue_numbers,
      occurred_at: occurred_at
    )
  end
end

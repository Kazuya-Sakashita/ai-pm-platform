class BackfillReviewStateEvents < ActiveRecord::Migration[7.1]
  class MigrationReview < ActiveRecord::Base
    self.table_name = "reviews"
  end

  class MigrationReviewStateEvent < ActiveRecord::Base
    self.table_name = "review_state_events"
  end

  def up
    MigrationReview.find_each do |review|
      project_id = project_id_for(review)
      next unless project_id

      issue_numbers = review.issue_numbers.presence || []
      create_event!(
        review: review,
        project_id: project_id,
        event_type: "review_requested",
        from_status: nil,
        to_status: "open",
        issue_numbers: issue_numbers,
        occurred_at: review.created_at
      )

      next if review.status == "open"

      create_event!(
        review: review,
        project_id: project_id,
        event_type: event_type_for(review.status),
        from_status: "open",
        to_status: review.status,
        issue_numbers: issue_numbers,
        occurred_at: occurred_at_for(review)
      )
    end
  end

  def down
    MigrationReviewStateEvent.where("metadata ->> 'backfilled' = 'true'").delete_all
  end

  private

  def create_event!(review:, project_id:, event_type:, from_status:, to_status:, issue_numbers:, occurred_at:)
    MigrationReviewStateEvent.create!(
      review_id: review.id,
      project_id: project_id,
      target_type: review.target_type,
      target_id: review.target_id,
      event_type: event_type,
      from_status: from_status,
      to_status: to_status,
      actor_id: "system",
      reason_code: "legacy_backfill",
      issue_numbers: issue_numbers,
      metadata: { backfilled: true, actor_unknown: true },
      occurred_at: occurred_at || Time.current,
      created_at: Time.current,
      updated_at: Time.current
    )
  end

  def event_type_for(status)
    {
      "action_required" => "review_action_required",
      "resolved" => "review_resolved",
      "accepted_risk" => "review_risk_accepted"
    }.fetch(status)
  end

  def occurred_at_for(review)
    accepted_at = review.accepted_risk.to_h["accepted_at"] if review.status == "accepted_risk"
    accepted_at.present? ? Time.zone.parse(accepted_at) : review.updated_at
  rescue ArgumentError, TypeError
    review.updated_at
  end

  def project_id_for(review)
    case review.target_type
    when "meeting"
      select_project_id("SELECT project_id FROM meetings WHERE id = #{quoted(review.target_id)}")
    when "conversation_import"
      select_project_id("SELECT project_id FROM conversation_imports WHERE id = #{quoted(review.target_id)}")
    when "conversation_summary_draft"
      select_project_id(<<~SQL.squish)
        SELECT conversation_imports.project_id
        FROM conversation_summary_drafts
        INNER JOIN conversation_imports ON conversation_imports.id = conversation_summary_drafts.conversation_import_id
        WHERE conversation_summary_drafts.id = #{quoted(review.target_id)}
      SQL
    when "minutes"
      select_project_id(<<~SQL.squish)
        SELECT meetings.project_id
        FROM minutes
        INNER JOIN meetings ON meetings.id = minutes.meeting_id
        WHERE minutes.id = #{quoted(review.target_id)}
      SQL
    when "requirement"
      select_project_id(<<~SQL.squish)
        SELECT meetings.project_id
        FROM requirements
        INNER JOIN minutes ON minutes.id = requirements.minutes_id
        INNER JOIN meetings ON meetings.id = minutes.meeting_id
        WHERE requirements.id = #{quoted(review.target_id)}
      SQL
    when "issue_draft"
      select_project_id(<<~SQL.squish)
        SELECT meetings.project_id
        FROM issue_drafts
        INNER JOIN requirements ON requirements.id = issue_drafts.requirement_id
        INNER JOIN minutes ON minutes.id = requirements.minutes_id
        INNER JOIN meetings ON meetings.id = minutes.meeting_id
        WHERE issue_drafts.id = #{quoted(review.target_id)}
      SQL
    when "openapi_draft"
      select_project_id(<<~SQL.squish)
        SELECT meetings.project_id
        FROM open_api_drafts
        INNER JOIN requirements ON requirements.id = open_api_drafts.requirement_id
        INNER JOIN minutes ON minutes.id = requirements.minutes_id
        INNER JOIN meetings ON meetings.id = minutes.meeting_id
        WHERE open_api_drafts.id = #{quoted(review.target_id)}
      SQL
    end
  end

  def select_project_id(sql)
    connection.select_value(sql)
  end

  def quoted(value)
    connection.quote(value)
  end
end

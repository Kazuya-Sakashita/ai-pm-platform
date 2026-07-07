class CreateFailedJobDiscardApprovals < ActiveRecord::Migration[7.1]
  def change
    create_table :failed_job_discard_approvals, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      t.string :failed_job_id, null: false
      t.string :solid_queue_job_id, null: false
      t.uuid :product_job_id
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.string :reason_template, null: false
      t.boolean :discard_safety_confirmed, default: false, null: false
      t.string :status, default: "pending", null: false
      t.string :requested_by_actor_id, null: false
      t.string :requested_by_role
      t.string :approved_by_actor_id
      t.string :approved_by_role
      t.string :rejected_by_actor_id
      t.string :rejected_by_role
      t.string :consumed_by_actor_id
      t.string :consumed_by_role
      t.text :approval_note
      t.text :rejection_reason
      t.datetime :expires_at, null: false
      t.datetime :approved_at
      t.datetime :rejected_at
      t.datetime :consumed_at

      t.timestamps
    end

    add_index :failed_job_discard_approvals, [:project_id, :failed_job_id, :status], name: "idx_failed_job_discard_approvals_lookup"
    add_index :failed_job_discard_approvals, [:project_id, :failed_job_id, :reason_template],
      unique: true,
      where: "status IN ('pending', 'approved')",
      name: "idx_failed_job_discard_approvals_active_unique"
    add_index :failed_job_discard_approvals, [:project_id, :expires_at], name: "idx_failed_job_discard_approvals_expiry"
    add_index :failed_job_discard_approvals, :requested_by_actor_id, name: "idx_failed_job_discard_approvals_requester"
    add_index :failed_job_discard_approvals, :approved_by_actor_id, name: "idx_failed_job_discard_approvals_approver"
  end
end

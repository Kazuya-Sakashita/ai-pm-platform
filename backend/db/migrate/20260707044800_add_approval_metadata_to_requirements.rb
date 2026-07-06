class AddApprovalMetadataToRequirements < ActiveRecord::Migration[7.1]
  def change
    add_column :requirements, :approved_at, :datetime
    add_column :requirements, :approved_by, :string
    add_column :requirements, :approval_note, :text

    add_index :requirements, :approved_at
    add_index :requirements, [:approved_by, :approved_at]
  end
end

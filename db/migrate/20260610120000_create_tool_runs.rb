class CreateToolRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :tool_runs do |t|
      t.string :tool_type, null: false
      t.string :website
      t.string :company_name
      t.jsonb :inputs, null: false, default: {}
      t.jsonb :analysis, null: false, default: {}
      t.jsonb :result, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.text :error
      t.references :lead, foreign_key: true, null: true

      t.timestamps
    end

    add_index :tool_runs, :tool_type
    add_index :tool_runs, :status
  end
end

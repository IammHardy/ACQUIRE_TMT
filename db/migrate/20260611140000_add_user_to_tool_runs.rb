class AddUserToToolRuns < ActiveRecord::Migration[8.0]
  def change
    add_reference :tool_runs, :user, foreign_key: true, null: true
  end
end

class CreateDealAccesses < ActiveRecord::Migration[8.0]
  def change
    create_table :deal_accesses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :deal, null: false, foreign_key: true
      t.string :status, null: false, default: "requested"  # requested | approved | declined

      t.timestamps
    end
    add_index :deal_accesses, [:user_id, :deal_id], unique: true
  end
end

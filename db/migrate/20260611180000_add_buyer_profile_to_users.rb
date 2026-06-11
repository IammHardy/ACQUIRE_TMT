class AddBuyerProfileToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :buyer_type, :string
    add_column :users, :phone, :string
    add_column :users, :occupation, :string
    add_column :users, :bio, :text
    add_column :users, :experience_level, :string
    add_column :users, :funding_sources, :string, array: true, null: false, default: []
    add_column :users, :personal_liquidity, :string
    add_column :users, :ev_min, :bigint
    add_column :users, :ev_max, :bigint
    add_column :users, :ebitda_min, :bigint
    add_column :users, :ebitda_max, :bigint
    add_column :users, :geographic_focus, :string, array: true, null: false, default: []
    add_column :users, :additional_context, :text
    add_column :users, :approval_status, :string, null: false, default: "incomplete"
  end
end

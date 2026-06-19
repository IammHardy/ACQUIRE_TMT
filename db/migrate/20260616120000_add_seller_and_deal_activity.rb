class AddSellerAndDealActivity < ActiveRecord::Migration[8.0]
  def change
    add_reference :deals, :user, foreign_key: true, null: true # the seller who owns this listing

    create_table :offers do |t|
      t.references :deal, null: false, foreign_key: true
      t.string :buyer_name, null: false
      t.string :buyer_kind                # Private Equity | Corporate | Individual
      t.bigint :purchase_price
      t.integer :upfront_cash_pct
      t.integer :seller_note_pct
      t.integer :equity_rollover_pct
      t.string :status, null: false, default: "new"
      t.timestamps
    end

    create_table :meetings do |t|
      t.references :deal, null: false, foreign_key: true
      t.string :buyer_name, null: false
      t.datetime :scheduled_at
      t.string :note
      t.string :status, null: false, default: "scheduled"
      t.timestamps
    end
  end
end

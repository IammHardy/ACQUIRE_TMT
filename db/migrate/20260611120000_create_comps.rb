class CreateComps < ActiveRecord::Migration[8.0]
  def change
    create_table :comps do |t|
      t.string :industry, null: false
      t.string :name, null: false
      t.text :description
      t.bigint :revenue
      t.bigint :earnings          # SDE / EBITDA
      t.bigint :sale_price
      t.decimal :revenue_multiple, precision: 6, scale: 2
      t.decimal :earnings_multiple, precision: 6, scale: 2
      t.boolean :recurring, null: false, default: false
      t.string :kind, null: false, default: "benchmark"  # benchmark | transaction
      t.string :period            # e.g. "2025"
      t.string :source
      t.string :source_url

      t.timestamps
    end

    add_index :comps, :industry
    add_index :comps, [:industry, :name], unique: true
  end
end

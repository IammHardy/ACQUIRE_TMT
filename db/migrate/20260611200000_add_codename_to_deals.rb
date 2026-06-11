class AddCodenameToDeals < ActiveRecord::Migration[8.0]
  def change
    add_column :deals, :codename, :string
  end
end

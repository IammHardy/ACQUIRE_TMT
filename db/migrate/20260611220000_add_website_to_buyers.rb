class AddWebsiteToBuyers < ActiveRecord::Migration[8.0]
  def change
    add_column :buyers, :website, :string
  end
end

class AddNamesToMarkets < ActiveRecord::Migration
  def change
    add_column :markets, :primary_currency_name, :string
    add_column :markets, :secondary_currency_name, :string
    add_column :markets, :state, :string, :default => 'inactive'
  end
end

class CreateMarkets < ActiveRecord::Migration
  def change
    create_table :markets do |t|
      t.string :marketid
      t.string :label
      t.string :primary_currency_code
      t.string :secondary_currency_code

      t.timestamps
    end

    add_index :markets, :marketid
    add_index :markets, :label
  end
end

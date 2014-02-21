class CreateMarketOrders < ActiveRecord::Migration
  def change
    create_table :market_orders do |t|
      t.belongs_to :market
      t.string :marketid
      t.string :order_type
      t.decimal :price
      t.decimal :quantity
      t.decimal :total

      t.timestamps
    end

    add_index :market_orders, :marketid
    add_index :market_orders, :market_id
    add_index :market_trades, :marketid
    add_index :market_trades, :market_id

  end
end

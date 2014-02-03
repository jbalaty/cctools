class CreateMarketTrades < ActiveRecord::Migration
  def change
    create_table :market_trades do |t|
      t.belongs_to :market
      t.string :marketid
      t.string :tradeid
      t.datetime :datetime
      t.decimal :tradeprice
      t.decimal :quantity
      t.decimal :total
      t.string  :initiate_ordertype

      t.timestamps
    end

    add_index :market_trades, :tradeid

  end
end

class CreateCandlesticks < ActiveRecord::Migration
  def change
    create_table :candlesticks do |t|
      t.belongs_to :market
      t.string :marketid
      t.datetime :interval_start
      t.datetime :interval_end
      t.integer :interval_seconds
      t.decimal :open
      t.decimal :close
      t.decimal :high
      t.decimal :low
      t.decimal :volume_buy
      t.decimal :volume_sell
      t.integer :num_buy_trades
      t.integer :num_sell_trades
      t.string :direction, length: 1
      #t.decimal :high_buy
      #t.decimal :high_sell
      #t.decimal :low_buy
      #t.decimal :low_sell

      t.timestamps
    end

    add_index :candlesticks, :market_id
    add_index :candlesticks, :marketid
    add_index :candlesticks, :interval_start
    add_index :candlesticks, :interval_end
    add_index :candlesticks, :interval_seconds
  end
end

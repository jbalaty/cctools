class CreateCandlesticks < ActiveRecord::Migration
  def change
    create_table :candlesticks do |t|
      t.string :market_label
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
      #t.decimal :high_buy
      #t.decimal :high_sell
      #t.decimal :low_buy
      #t.decimal :low_sell

      t.timestamps
    end
  end
end

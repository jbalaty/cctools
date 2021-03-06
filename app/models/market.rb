class Market < ActiveRecord::Base
  has_many :market_trades, dependent: :destroy
  has_many :market_orders, dependent: :destroy
  has_many :candlesticks, dependent: :destroy
end

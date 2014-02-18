class Market < ActiveRecord::Base
  has_many :market_trades, dependent: :destroy
  has_many :market_orders, dependent: :destroy
end

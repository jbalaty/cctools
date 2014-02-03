class Market < ActiveRecord::Base
  has_many :market_trades, dependent: :destroy
end

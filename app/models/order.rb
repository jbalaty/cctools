class Order < ActiveRecord::Base

  def self.find_orders_for_market(market_label, state)
    self.where("state=? AND market_label=?", state, market_label)
  end
end

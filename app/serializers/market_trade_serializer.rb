class MarketTradeSerializer < ActiveModel::Serializer
  attributes :id, :marketid, :tradeid, :datetime, :tradeprice, :quantity, :total, :initiate_ordertype
end

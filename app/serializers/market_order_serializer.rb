class MarketOrderSerializer < ActiveModel::Serializer
  attributes :id, :order_type, :price, :quantity, :total
end

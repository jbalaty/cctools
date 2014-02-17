class MarketSerializer < ActiveModel::Serializer
  attributes :id, :label, :marketid, :primary_currency_code, :primary_currency_name,:secondary_currency_code, :secondary_currency_name
end

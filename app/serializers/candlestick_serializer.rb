class CandlestickSerializer < ActiveModel::Serializer
  attributes :id, :marketid, :interval_start, :interval_end, :interval_seconds, :open, :close, :high, :low
end

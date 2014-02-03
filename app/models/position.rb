class Position < ActiveRecord::Base
  has_one :input_order, :class_name => 'Order'
  has_one :output_order, :class_name => 'Order'

end

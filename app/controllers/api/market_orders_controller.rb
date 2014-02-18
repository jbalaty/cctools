class Api::MarketOrdersController < ApplicationController
  respond_to :json
  after_filter :cors_set_access_control_headers

  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
  end

  def index
    @market_orders = MarketOrder.where('marketid=?', params['marketid'])
    @sellorders = []
    @buyorders = []
    @market_orders.each do |mo|
      if mo.order_type == 'Sell'
        @sellorders << mo
      elsif mo.order_type == 'Buy'
        @buyorders << mo
      else
        raise Error('Wrong market order type')
      end
    end
    #return respond_with({sellorders: @sellorders, buyorders: @buyorders})
    return respond_with(@market_orders)
  end
end

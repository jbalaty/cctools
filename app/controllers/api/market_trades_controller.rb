class Api::MarketTradesController < ApplicationController
  respond_to :json
  after_filter :cors_set_access_control_headers

  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    #headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
    #headers['Access-Control-Allow-Headers'] = '*'
    #headers['Access-Control-Max-Age'] = "1728000"
  end

  # GET /markets.json
  def index
    @market_trades = MarketTrade.where('marketid=? AND created_at>=?', params['marketid'], Time.now-1.day).order('datetime desc').take 100
    return respond_with(@market_trades)
  end
end

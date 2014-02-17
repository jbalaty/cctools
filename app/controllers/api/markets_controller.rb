class Api::MarketsController < ApplicationController
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
    @markets = Market.where('state=?','active').order('label asc')
    return respond_with(@markets)
  end

  # GET /markets.json
  def show
    @market = Market.where('id=?', params['id'])
    return respond_with(@market)
  end

end

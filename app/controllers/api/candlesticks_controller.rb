class Api::CandlesticksController < ApplicationController
  respond_to :json
  after_filter :cors_set_access_control_headers

  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
  end

  def index
    filtered_params = params.permit(:marketid, :interval_seconds)
    if filtered_params[:interval_seconds].to_i == 60
      filtered_params[:interval_start] = Time.now - 6.hours
    elsif filtered_params[:interval_seconds].to_i == 900
      filtered_params[:interval_start] = Time.now - 1.day
    else
      raise Error('Cannot process this interval_seconds type')
    end
    unless filtered_params[:marketid]
      raise Error('Marketid required')
    end
    @candlesticks = Candlestick.where('marketid=? AND interval_seconds=? AND interval_start>=?', filtered_params[:marketid],
                      filtered_params[:interval_seconds], filtered_params[:interval_start]).order('interval_start asc')
    return respond_with(@candlesticks)
  end

end

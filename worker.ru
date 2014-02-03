# encoding:UTF-8
require 'ansi/code'

require_relative 'config/environment.rb'
require_relative 'lib/workers/cryptsy/api'
require_relative 'lib/workers/market_place_tool'


@sleep_time = 30 #seconds


program_start = Time.now


default_market_settings = {
    trades: {
        ignore_total_lower_than: 0.0001 # dont store trades with very low volume of traded coins
    },
    ats: {# automatic trade system
          quantity: 100
    }
}

markets_settings = {
    'DOGE/BTC' => {
        ats: {# automatic trade system
              quantity: 100
        }
    },
    'LTC/BTC' => {
        ats: {# automatic trade system
              quantity: 0.2
        }
    },
    'QRK/BTC' => {
        trades: {
            ignore_total_lower_than: 0.00009
        },
        ats: {# automatic trade system
              quantity: 2
        }
    },
    'CSC/BTC' => {
        ats: {# automatic trade system
              quantity: 4
        }
    },
    'MEC/BTC' => {
        ats: {# automatic trade system
              quantity: 0.20
        }
    },
    'FTC/BTC' => {
        ats: {# automatic trade system
              quantity: 0.20
        }
    },
    #'DOGE/LTC' => {}
}
                 # merge with default settings
markets_settings.each do |k, v|
  merged = default_market_settings.merge(v)
  markets_settings[k] = merged
end

markets_filter = ['DOGE/BTC', 'LTC/BTC', 'QRK/BTC']
markets_of_interest = markets_settings.select { |key| markets_filter.include? key }
markets_of_interest.each { |k, v| puts "Market settings for #{k}: #{v.inspect}" }

key=Cctools::Application.config.cryptsy_key
secret=Cctools::Application.config.cryptsy_secret
market_place = MarketPlaceTool.new(key, secret)
last_market_refresh_time = GlobalValues.find_by_key('last_markets_refresh_time') || GlobalValues.new({'key' => 'last_markets_refresh_time', 'value' => (Time.now - 1.year).to_s})

@feature_use_stat_thread = false

def stat_thread_func(market_place, markets_of_interest)
  market_place.load_market_trades(markets_of_interest)
  sleep(@sleep_time)
end


rule_one_down_and_then_up_or_stable = Proc.new do |candlestics|
  result = nil
  if candlestics.length > 3
    current = candlestics.last
    previous1 = candlestics.fetch(-2)
    previous2 = candlestics.fetch(-3)
    previous3 = candlestics.fetch(-4)
    if (
    (previous1[:direction]=='down' && previous1[:close]/ previous1[:open] < 0.98) ||
        (previous1[:direction]=='down' && previous2[:direction]=='down' && previous1[:close]/previous2[:open] < 0.975) ||
        (previous1[:direction]=='down' && previous2[:direction]=='down' && previous3[:direction]=='down' && previous1[:close]/previous3[:open] < 0.97)
    ) &&
        (current[:direction] == 'up' || current[:direction] == '-')
      result = {}
      result[:open_price] = current[:close] * 1.0
      result[:close_price] = current[:close]*1.01
      result[:cancel_price] = current[:close]*0.998
    end
  end
  result
end

# main program loop
puts '-----------------------------------------------------------------'
loop_run = true
while loop_run do
  loop_start = Time.now
  # refresh markets
  refresh_markets = Market.all.length == 0 || (Time.now - last_market_refresh_time.get_datetime) > 60*60*12 # 12 hours
  if refresh_markets
    market_place.refresh_markets
    last_market_refresh_time.value = Time.now.to_s
    last_market_refresh_time.save!
  end

  # load market trades data
  if @feature_use_stat_thread
    stat_thread = Thread.new { stat_thread_func(market_place, markets_of_interest) }
  else
    markets_of_interest.each do |market_label, settings|
      market_place.load_market_trades(market_label, settings)
    end
  end
  puts '-----------------------------------------------------------------'
  market_place.load_my_trades
  market_place.process_orders

  market_place.delete_old_market_trades
  puts '-----------------------------------------------------------------'
  markets_of_interest.each do |market_label, settings|
    puts "Test ATS rules for #{market_label}"
    trades = market_place.get_trades(market_label, Time.now-7.days)
    candlesticks = market_place.generate_candlesticks trades
    test_result = market_place.test_rule candlesticks, &rule_one_down_and_then_up_or_stable

    color = if test_result[:win_rate] > 1.0 then
              ANSI.green
            else
              ANSI.red
            end
    puts "#{color}-----------------------------------------------------#{ANSI.reset}"
    puts "#{color}Num wins: #{test_result[:wins]} - Num losts: #{test_result[:fails]} = score: #{test_result[:win_rate]}#{ANSI.reset}"
    puts "#{color}-----------------------------------------------------#{ANSI.reset}"
  end

  loop_time = Time.now - loop_start
  puts "Loop time: #{loop_time} seconds"
  # sleep for some time
  loop_run = true
  if loop_run
    puts '================================================================='
    sleep_time = [@sleep_time - loop_time, 10].max
    puts "Sleeping for #{sleep_time} seconds"
    sleep(sleep_time)
    puts '================================================================='
  end
end

if @feature_use_stat_thread
  puts "Waiting for stat_thread to join"
  stat_thread.join()
end
puts "Program time: #{Time.now - program_start} seconds"


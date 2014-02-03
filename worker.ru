# encoding:UTF-8
require 'ansi/code'

require_relative 'config/environment.rb'
require_relative 'lib/workers/cryptsy/api'
require_relative 'lib/workers/market_place_tool'


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

@sleep_time = 30 #seconds
program_start = Time.now
key=Cctools::Application.config.cryptsy_key
secret=Cctools::Application.config.cryptsy_secret
if key == nil || secret == nil
  raise 'Empty cryptsy key or secret'
end
market_place = MarketPlaceTool.new(key, secret)
last_market_refresh_time = GlobalValues.find_by_key('last_markets_refresh_time') || GlobalValues.new({'key' => 'last_markets_refresh_time', 'value' => (Time.now - 1.year).to_s})

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

  markets_of_interest.each do |market_label, settings|
    market_place.load_market_trades(market_label, settings)
  end
  puts '-----------------------------------------------------------------'
  market_place.load_my_trades
  market_place.process_orders

  market_place.delete_old_market_trades

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

puts "Program time: #{Time.now - program_start} seconds"


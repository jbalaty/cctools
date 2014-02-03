# encoding:UTF-8
require 'ansi/code'

require_relative 'config/environment.rb'
require_relative 'lib/workers/cryptsy/api'
require_relative 'lib/workers/market_place_tool'


default_market_settings = {
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

#markets_filter = ['DOGE/BTC', 'LTC/BTC', 'QRK/BTC']
markets_filter = ['DOGE/BTC']
markets_of_interest = markets_settings.select { |key| markets_filter.include? key }
markets_of_interest.each { |k, v| puts "Market settings for #{k}: #{v.inspect}" }


@sleep_time = 30 #seconds
program_start = Time.now
key=Cctools::Application.config.cryptsy_key
secret=Cctools::Application.config.cryptsy_secret
market_place = MarketPlaceTool.new(key, secret)
last_market_refresh_time = GlobalValues.find_by_key('last_markets_refresh_time') || GlobalValues.new({'key' => 'last_markets_refresh_time', 'value' => (Time.now - 1.year).to_s})

rules = {}
rules[:rule_one_down_and_then_up_or_stable] = Proc.new do |candlestics|
  result = nil
  if candlestics.length > 3
    current = candlestics.last
    previous1 = candlestics.fetch(-2)
    previous2 = candlestics.fetch(-3)
    previous3 = candlestics.fetch(-4)
    if (
      (previous1[:direction]=='down'
      #&& previous1[:close]/ previous1[:open] < 0.95) ||
      #(previous1[:direction]=='down' && previous2[:direction]=='down' && previous1[:close]/previous2[:open] < 0.975) ||
      #(previous1[:direction]=='down' && previous2[:direction]=='down' && previous3[:direction]=='down' && previous1[:close]/previous3[:open] < 0.97)
      )
    ) &&
        (current[:direction] == 'up' || current[:direction] == '-')
      result = {}
      result[:open_price] = current[:close] * 1.0
      result[:close_price] = current[:close]*1.020
      result[:cancel_price] = current[:close]*0.98
    end
  end
  result
end


def print_test_result(test_result, format = :full)
  color = if test_result[:win_rate] > 1.0 then
            ANSI.green
          else
            ANSI.red
          end
  puts "#{color}-----------------------------------------------------#{ANSI.reset}"
  if format == :full
    puts "#{color}Results for market #{test_result[:market_label]} - rule: #{test_result[:rule]} #{ANSI.reset}"

  end
  puts "#{color}Num wins: #{test_result[:wins]} - Num losts: #{test_result[:fails]} = score: #{test_result[:win_rate]}#{ANSI.reset}"
  puts "#{color}-----------------------------------------------------#{ANSI.reset}"
end

# main program loop
puts '-----------------------------------------------------------------'
loop_run = true
while loop_run do
  loop_start = Time.now

  all_results = []
  markets_of_interest.each do |market_label, settings|
    puts "Test ATS rules for #{market_label}"
    trades = market_place.get_trades(market_label, Time.now-7.days)
    candlesticks = market_place.generate_candlesticks trades, 300
    test_result = market_place.test_rule candlesticks, &rules.values.first
    test_result[:market_label] = market_label
    test_result[:rule] = rules.keys.first

    print_test_result test_result
    all_results << test_result
  end

  puts '#################################################################'
  all_results.each { |result| print_test_result result }

  loop_time = Time.now - loop_start
  puts "Loop time: #{loop_time} seconds"
  # sleep for some time
  loop_run = false
  if loop_run
    puts '================================================================='
    sleep_time = [@sleep_time - loop_time, 10].max
    puts "Sleeping for #{sleep_time} seconds"
    sleep(sleep_time)
    puts '================================================================='
  end
end
puts "Program time: #{Time.now - program_start} seconds"


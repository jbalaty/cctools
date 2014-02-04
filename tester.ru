# encoding:UTF-8
require 'ansi/code'
require 'slop'

require_relative 'config/environment.rb'
require_relative 'lib/workers/cryptsy/api'
require_relative 'lib/workers/market_place_tool'


#options parsing
opts = Slop.parse do
  banner 'Usage: tester.ru [options]'

  on 'cslen=', 'Generated candlestick lenght'
  on 'v', 'verbose', 'Enable verbose mode'
end

# if ARGV is `--name Lee -v`
#opts.verbose?  #=> true
puts "Cmd arguments: #{opts.to_hash.inspect}"


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

# default constants
@candlestick_interval_lenght = if opts[:cslen] && opts[:cslen].to_i > 10 then
                                 opts[:cslen].to_i
                               else
                                 300
                               end


@sleep_time = 30 #seconds
program_start = Time.now
key=Cctools::Application.config.cryptsy_key
secret=Cctools::Application.config.cryptsy_secret
market_place = MarketPlaceTool.new(key, secret)
last_market_refresh_time = GlobalValues.find_by_key('last_markets_refresh_time') || GlobalValues.new({'key' => 'last_markets_refresh_time', 'value' => (Time.now - 1.year).to_s})

rules = {}
rules[:rule_one_down_and_then_up_or_stable] = Proc.new do |csticks|
  result = nil
  min_stack_length = 50
  if csticks.ensure_backlook min_stack_length
    mavg_short = csticks.avg_close 5 #moving avg for last 5 candlesticks
    mavg_short_prev = csticks.previous_step_state().avg_close 5 #moving avg for last 5 candlesticks
    mavg_medium = csticks.avg_close min_stack_length / 2
    #mavg_long_prev = csticks.previous_step_state(1).avg_close min_stack_length / 2
    mavg_long = csticks.avg_close min_stack_length
    mavg_long_prev = csticks.previous_step_state(1).avg_close min_stack_length

    #raising market price is above moving average
    if csticks.close(0) > mavg_long && mavg_long > mavg_long_prev #&& csticks.close(0) >= (mavg_long + (mavg_long-mavg_medium).abs*55)
      if  (mavg_short> mavg_short_prev)
        #((csticks.direction(0) == 'up' || csticks.direction(0) == '-') && csticks.direction(1) == 'up') &&
        #(csticks.direction(1) == 'down' || csticks.direction(1) == '-')
        (csticks.close(0) > mavg_short && mavg_short >= mavg_long_prev)
        result = {}
        result[:open_price] = csticks.close * 1.0
        result[:close_price] = csticks.close * 1.012
        #result[:running_close_drop] = 0.99 # close this position when up trends drops bellow X% of previous max close
        result[:cancel_price] = csticks.close * 0.99
      end
    else # falling market, price is below moving average
         #buy_limit = all_avg * 0.975
         #puts "Market is falling, not trading"
    end
    #(csticks.direction(2)=='down' || csticks.direction(2) == '-' || csticks.direction(1)=='down' || csticks.direction(1) == '-')
    #(previous1[:direction]=='down' && previous2[:direction]=='down' && previous1[:close]/previous2[:open] < 0.975) ||
    #(previous1[:direction]=='down' && previous2[:direction]=='down' && previous3[:direction]=='down' && previous1[:close]/previous3[:open] < 0.97)
  end
  result
end


def print_test_result(test_result, format = :full)
  color = if test_result[:total_gain] > 0 then
            ANSI.green
          else
            ANSI.red
          end
  puts "#{color}-----------------------------------------------------#{ANSI.reset}"
  if format == :full
    puts "#{color}Results for market #{test_result[:market_label]} - rule: #{test_result[:rule]} #{ANSI.reset}"

  end
  puts "#{color}Num wins: #{test_result[:wins]} - Num losts: #{test_result[:fails]} = score: #{test_result[:win_rate]} (+#{test_result[:waiting]} still waiting | +#{test_result[:discarded]} discarded)#{ANSI.reset}"
  puts "#{color}Gain: #{test_result[:total_gain]} (#{sprintf '%.2f', test_result[:total_gain]*100} %)#{ANSI.reset}"
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
    candlesticks = market_place.generate_candlesticks trades, @candlestick_interval_lenght
    test_result = market_place.test_rule candlesticks, &rules.values.first
    test_result[:market_label] = market_label
    test_result[:rule] = rules.keys.first
    market_place.export_to_csv("cs-#{market_label.tr('/','#')}-int#{@candlestick_interval_lenght}.csv", candlesticks)

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


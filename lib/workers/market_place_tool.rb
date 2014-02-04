# encoding:UTF-8
require 'ansi/code'
require 'csv'
require_relative 'cryptsy/api'
require_relative 'candle_sticks_helper'


class MarketPlaceTool
  MarketPlaceName = 'Cryptsy'


  def initialize(key, secret)
    @cryptsy = Cryptsy::API::Client.new(key, secret)
    @cryptsy_timeshift = -5.hours
    @cryptsy_transaction_fee = 0.005 # buy 0.2%, sell 0.3% = 0.5% for buy/sell transaction
    @order_ttl = 30.seconds
  end

  def refresh_markets
    puts MarketPlaceName + 'Refreshing markets data'
    markets_items = do_request { @cryptsy.getmarkets }
    markets_items.each do |market_item|
      market = Market.find_by_marketid market_item['marketid']
      filtered_mi = market_item.select { |k| ['marketid', 'label', 'primary_currency_code', 'secondary_currency_code'].include?(k) }
      unless market
        puts "Creating new market #{filtered_mi['label']}"
        market = Market.new filtered_mi
      else
        puts "Updating market #{filtered_mi['label']}"
        market.update filtered_mi
      end
      market.save!
    end
    puts '-----------------------------------------------------------------'
  end

  def load_orders(markets_config)
    markets_config.each do |key|
      market = Market.find_by_label key
      min_total = 0.0001
      min_sell_quantity = 1000
      min_buy_quantity = 2000
      if market
        market_id = market['marketid']
        puts "Loading market order for #{key} - marketid = #{market_id}"
        market_orders = do_request { @cryptsy.marketorders(market_id) }
        filtered_sell_orders = market_orders['sellorders'].select { |item| item['quantity'].to_f > min_sell_quantity }
        filtered_buy_orders = market_orders['buyorders'].select { |item| item['quantity'].to_f > min_buy_quantity }

        lowest_sell_order = filtered_sell_orders.first
        second_lowest_sell_order = filtered_sell_orders.second
        highest_buy_order = filtered_buy_orders.first
        second_highest_buy_order = filtered_buy_orders.second
        buyprice1 = lowest_sell_order['sellprice'].to_f
        buyprice2 = second_lowest_sell_order['sellprice'].to_f
        sellprice1 = highest_buy_order['buyprice'].to_f
        sellprice2 = second_highest_buy_order['buyprice'].to_f
        puts "Lowest sell order: #{lowest_sell_order['sellprice']} | quantity: #{lowest_sell_order['quantity']}"
        puts "Second lowest sell order: #{second_lowest_sell_order['sellprice']} | quantity: #{second_lowest_sell_order['quantity']}"
        puts "Highest buy order: #{highest_buy_order['buyprice']} | quantity: #{highest_buy_order['quantity']}"
        puts "Second highest buy order: #{second_highest_buy_order['buyprice']} | quantity: #{second_highest_buy_order['quantity']}"
        sb_rate = sellprice1 / buyprice1
        sb_rate_string = sprintf '%0.3f', sb_rate*100
        if sb_rate>1.0
          color = ANSI.reset
          if sb_rate > 1.04
            color = ANSI.yellow
          elsif sb_rate > 1.03
            color = ANSI.red
          elsif sb_rate > 1.02
            color = ANSI.magenta
          elsif sb_rate > 1.01
            color = ANSI.blue
          end
          puts "#{color}Buy price < sell price S1/B1=#{sb_rate_string}%#{ANSI.reset}"
        else
          puts "Sell price < buy price S1/B1=#{sb_rate_string}%"
        end
      else
        puts "Cannot find marketid for #{key}"
      end
      puts '-----------------------------------------------------------------'
    end
  end

  def load_market_trades(market_label, market_settings)
    market = Market.find_by_label market_label
    min_total = market_settings[:trades][:ignore_total_lower_than]
    if market
      market_id = market['marketid']
      puts "Loading market trades for #{market_label} - marketid = #{market_id}"
      market_trades = do_request { @cryptsy.markettrades(market_id) }
      new_trades_counter = 0
      puts "Processing market trades #{market_trades.length}"
      market_trades.each do |mt|
        if mt['total'].to_f >= min_total
          market_trade = MarketTrade.find_by_tradeid mt['tradeid']
          unless market_trade
            #puts "Storing new market trade ID=#{mt['tradeid']} - #{mt['initiate_ordertype']}"
            market_trade = MarketTrade.new mt
            market_trade.marketid=market_id
            market.market_trades << market_trade
            new_trades_counter += 1
          else
            break
          end
        else
          puts "Ignoring this trade (total #{mt['total']} < min total #{sprintf('%.8f', min_total)}) BTC"
        end
      end
      puts "#{new_trades_counter}/#{market_trades.length} new market trades"
      market.save!
    else
      puts "Cannot find marketid for #{market_label}"
    end
  end

  def get_trades(market_label, from, to = Time.now+1.hour)
    market = Market.find_by_label market_label
    if market
      return MarketTrade.where('marketid=? AND (? <= datetime AND datetime <= ?)', market['marketid'], from + @cryptsy_timeshift,
                               to + @cryptsy_timeshift).order('datetime asc')
    else
      puts "Cannot find marketid for #{market_label}"
    end
  end

  def test_rule(candlesticks, &block)
    stack = []
    position_cmds = []
    position_cmd = nil
    cmd_state = nil
    candlesticks.each do |cs|
      stack << cs
      unless position_cmd || cmd_state == :wait_buy
        position_cmd = yield CandleSticksHelper.new(stack)
        if position_cmd
          cmd_state = :wait_buy
          new_position = true
          position_cmd[:created_index] = cs[:index]
          position_cmds << position_cmd
        end
      else
        cmd_state = process_command position_cmd, stack.last, cmd_state
        if cmd_state == :finished
          position_cmd = nil
        elsif cmd_state == :canceled
          position_cmd = nil
        elsif cmd_state == :discarded
          position_cmd = nil
        end
      end
      #prepare color
      color = ANSI.reset
      if new_position
        color = ANSI.red
      end
      puts "#{ANSI.reset}#{format_dt cs[:interval_start]} - #{format_dt cs[:interval_end]} :: O:#{format_price cs[:open]}|C:#{format_price cs[:close]} || H:#{format_price cs[:high]}|L:#{format_price cs[:low]} (#{cs[:trades].length} trades)| dir #{cs[:direction]}} #{ANSI.reset}"
      if new_position
        puts "#{color}New position command: " + position_cmd.inspect + ANSI.reset.to_s
      end
    end

    num_finished = position_cmds.count { |p| p[:resolution]==:finished }
    num_canceled = position_cmds.count { |p| p[:resolution]==:canceled }
    num_discarded = position_cmds.count { |p| p[:resolution]==:discarded }
    num_waiting = position_cmds.count { |p| p[:resolution] == nil }
    position_cmds.each do |p|
      if p[:trade_close_price] && p[:trade_open_price]
        p[:gain] = (p[:trade_close_price]/p[:trade_open_price]) - 1.0 - @cryptsy_transaction_fee
      end
    end


    return {
        wins: num_finished,
        fails: num_canceled,
        waiting: num_waiting,
        discarded: num_discarded,
        win_rate: (num_finished - num_canceled),
        positions: position_cmds,
        total_gain: position_cmds.select{|p| p[:resolution]!=:discarded}.map { |p| p[:gain] || 0 }.sum
    }
  end

  def process_command(command, current_candlestick, state)
    if state == :wait_buy && current_candlestick[:index] - command[:created_index] > 2
      #if buy command is not executed in the next round, cancel the command
      state = :discarded
      command[:trade_close_price] = command[:trade_open_price] = 0.0
      command[:resolution] = :discarded
      command[:running_max_close_price] = nil
      puts "#{ANSI.blue}Canceling this command, it was not executed in the next round #{format_price command[:open_price]} (#{command.inspect})#{ANSI.reset}"
    elsif state == :wait_buy && (current_candlestick[:buy_low] || Float::MAX) <= command[:open_price] && current_candlestick[:quantity] > 0
      state = :bought
      command[:trade_open_price] = command[:open_price]
      command[:running_max_close_price] = current_candlestick[:close]
      puts "#{ANSI.blue}Activating command with price #{format_price command[:open_price]} | min:#{format_price current_candlestick[:buy_low]} (#{command.inspect})#{ANSI.reset}"
    elsif state == :bought
      #if command[:close_price]
      if (current_candlestick[:sell_high] || Float::MIN) >= command[:close_price] && current_candlestick[:quantity] > 0
        state = :finished
        command[:trade_close_price] = command[:close_price]
        command[:resolution] = :finished
        command[:running_max_close_price] = nil
        puts "#{ANSI.green}Finishing command with price #{format_price command[:close_price]} | max:#{format_price current_candlestick[:sell_high]} (#{command.inspect})#{ANSI.reset}"
        gain = command[:trade_close_price] / command[:trade_open_price] - 1.0 - @cryptsy_transaction_fee
        color = if gain>0
                  ANSI.green
                else
                  ANSI.yellow
                end
        puts "#{color} Gain; #{sprintf '%0.2f', gain*100} % (buy price #{format_price command[:trade_open_price]} | sell price #{format_price command[:trade_close_price]}) #{ANSI.reset}"
        #else
        #  command[:close_price] = current_candlestick[:close]
        #end
      elsif command[:running_close_drop] && current_candlestick[:close] <= (command[:running_max_close_price] * command[:running_close_drop]) && current_candlestick[:quantity] > 0
        command[:close_price] = current_candlestick[:close]*0.998
        puts "#{ANSI.blue}Starting sellout procedure for #{format_price command[:close_price]} | max running close:#{format_price command[:running_max_close_price]} (#{command.inspect})#{ANSI.reset}"
        command[:running_max_close_price] = nil
      elsif current_candlestick[:close] < command[:cancel_price]
        state = :canceled
        command[:trade_close_price] = current_candlestick[:close]
        command[:resolution] = :canceled
        command[:running_max_close_price] = nil
        puts "#{ANSI.yellow}Canceling command with price #{format_price current_candlestick[:close]} (#{command.inspect})#{ANSI.reset}"
        gain = command[:trade_close_price] / command[:trade_open_price] - 1.0 - @cryptsy_transaction_fee
        puts "#{ANSI.yellow} Gain; #{sprintf '%0.2f', gain*100} % (buy price #{format_price command[:trade_open_price]} | sell price #{format_price command[:trade_close_price]}) #{ANSI.reset}"
      else
        command[:running_max_close_price] = [command[:running_max_close_price], current_candlestick[:close]].max
      end
    end

    return state
  end

  def load_my_trades
    my_trades = do_request { @cryptsy.allmytrades }.take 200
    my_trades.each do |mt|
      order = Order.find_by_extern_id mt['order_id']
      if order
        if order.state != 'closed'
          order.state = 'closed'
          order.save!
        end
        # find apropriate positions
        position = Position.find_by_input_order_id(order.id)
        if position
          position.state = :active
          position.save!
        else
          position = Position.find_by_output_order_id(order.id)
          if position
            position.state = 'closed'
            position.save!
          else
            puts "Cannot find opened or active position for my trade: #{mt['tradeid']}(Type: #{mt['tradetype']}, Order: #{mt['order_id']})"
          end
        end
      else
        #puts "Cannot find order for for my trade: #{mt['tradeid']}(Type: #{mt['tradetype']}, Order: #{mt['order_id']})"
      end

    end
  end

  def generate_candlesticks(trades, length_secs = 60)
    puts "Generating candlesticks from trades (num of trades: #{trades.length}) interval lenght: #{length_secs} seconds (#{length_secs/60.0} minutes)"
    dt_first = trades.first['datetime'].change(min: 0)
    candlesticks = []
    # divide trades into intervals
    trades.each do |t|
      dt = t['datetime']
      secs = dt - dt_first
      group = (secs / length_secs).to_i
      cs = candlesticks[group]
      unless cs
        cs = candlesticks[group] = {trades: []}
      end
      cs[:trades] << t

    end
    # fill gaps (some intervals can be empty) and compute start/end
    candlesticks.each_index do |index|
      candlesticks[index] = candlesticks[index] || {trades: []}
      candlesticks[index][:interval_start] = dt_first + (index*length_secs).seconds
      candlesticks[index][:interval_end] = candlesticks[index][:interval_start] + length_secs.seconds
    end
    # trim empty intervals from start of the array
    while candlesticks.first == nil || candlesticks.first[:trades].length == 0
      candlesticks.shift
    end

    # compute OHCL
    last_cs = candlesticks.first
    candlesticks.each_index do |index|
      cs = candlesticks[index]
      unless cs[:trades].empty?
        open = cs[:trades].first['tradeprice'].to_f
        close = cs[:trades].last['tradeprice'].to_f
        high = cs[:trades].map { |i| i['tradeprice'].to_f }.max
        low = cs[:trades].map { |i| i['tradeprice'].to_f }.min
        quantity = cs[:trades].map { |i| i['quantity'].to_f }.sum
        buy_high = cs[:trades].select { |i| i['initiate_ordertype']=='Buy' }.map { |i| i['tradeprice'].to_f }.max
        buy_low = cs[:trades].select { |i| i['initiate_ordertype']=='Buy' }.map { |i| i['tradeprice'].to_f }.min
        sell_high = cs[:trades].select { |i| i['initiate_ordertype']=='Sell' }.map { |i| i['tradeprice'].to_f }.max
        sell_low = cs[:trades].select { |i| i['initiate_ordertype']=='Sell' }.map { |i| i['tradeprice'].to_f }.min
      else
        open = close = high = low = buy_high = buy_low = sell_high = sell_low =last_cs[:close]
        quantity = 0
      end
      cs[:index]=index
      cs[:open]=open
      cs[:close]=close
      cs[:high]=high
      cs[:low]=low
      cs[:quantity]=quantity
      cs[:buy_high]=buy_high
      cs[:buy_low]=buy_low
      cs[:sell_high]=sell_high
      cs[:sell_low]=sell_low
      #t_start = (dt_first + (index*length_secs).seconds) #.strftime("%H:%M")
      #t_end = (t_start + length_secs) #.strftime("%H:%M")
      #cs[:interval_start]=t_start
      #cs[:interval_end]=t_end

      #computed properties
      cs[:direction]= if open < close then
                        'up'
                      elsif close < open
                        'down'
                      else
                        '-'
                      end

      last_cs = cs
    end
    return candlesticks
  end

  def delete_old_market_trades(minutes = 60*24*7) # older than one week
    cryptsy_time = Time.now + @cryptsy_timeshift - minutes.minutes
    puts "Deleting market trades older than #{minutes} minutes => #{sprintf '%.3f', minutes/60.0/24.0} days (< cryptsy time: #{cryptsy_time})"
    MarketTrade.delete_all(['datetime < ?', cryptsy_time])
  end

  def create_order(market_label, quantity, price, type = :buy)
    puts "Creating order #{market_label} - quantity:#{quantity}, price: #{price}"
    order = Order.new
    order.market_label = market_label
    order.quantity = quantity
    order.price = price
    order.order_type = type.to_s.capitalize
    marketid = Market.find_by_label(order.market_label)['marketid']
    order.extern_id = do_request('orderid') { @cryptsy.createorder(marketid, order.order_type, order.quantity, order.price) }
    order.save!
    puts "Order created #{order.market_label} - ID=#{order.id} (EID:#{order.extern_id}, Price:#{order.price}, Quantity:#{order.quantity})"
    return order
  end

  def cancel_order(order)
    if order.state != 'closed' && order.state != 'canceled'
      puts "Canceling order #{order.market_label} ID=#{order.id} (EID:#{order.extern_id})"
      # cancel order
      do_request { @cryptsy.cancelorder(order.extern_id) }
      order.state = 'canceled'
      order.save!
    else
      raise Error('Cannot cancel order in this state: '+order.state)
    end
  end

  def process_orders
    puts "Processing opened orders older than #{@order_ttl} seconds"
    orders_to_cancel = Order.where('state=? AND created_at<=?', 'created', Time.now-@order_ttl)
    orders_to_cancel.each do |o|
      cancel_order o
    end
  end

  def open_position(market_label, options)
    puts "Opening new position at #{market_label} market"
    input_order = create_order(market_label, options[:quantity], options[:price]*0.5)
    position = Position.new
    position.input_order_id = input_order.id
    position.state = 'created'
    position.position_type = 'short 0% loss 1% gain'
    position.save!
    return position
  end

  def export_to_csv(filename, candlesticks)
    stack = []
    CSV.open(filename, "wb") do |csv|
      csv << ['index', 'start', 'end', '', 'open', 'close', 'high', 'low', '', 'num trades',
              'quantity', 'direction', nil, 'MAVG5', 'MAVG12', 'MAVG25', 'MAVG40', 'MAVG50', 'MAVG60', 'MAVG80', 'MAVG100']
      candlesticks.each do |cs|
        record = []
        record << cs[:index]
        record << cs[:interval_start].to_s
        record << cs[:interval_end].to_s
        record << nil
        record << cs[:open]
        record << cs[:close]
        record << cs[:high]
        record << cs[:low]
        record << nil
        record << cs[:trades].length
        record << cs[:quantity]
        record << cs[:direction]
        record << nil

        stack << cs
        cshelper = CandleSticksHelper.new(stack)
        if cshelper.ensure_backlook(5)
          record << cshelper.avg_close(5)
        else
          record << nil
        end
        if cshelper.ensure_backlook(12)
          record << cshelper.avg_close(12)
        else
          record << nil
        end
        if cshelper.ensure_backlook(25)
          record << cshelper.avg_close(25)
        else
          record << nil
        end
        if cshelper.ensure_backlook(40)
          record << cshelper.avg_close(40)
        else
          record << nil
        end
        if cshelper.ensure_backlook(50)
          record << cshelper.avg_close(50)
        else
          record << nil
        end
        if cshelper.ensure_backlook(60)
          record << cshelper.avg_close(60)
        else
          record << nil
        end
        if cshelper.ensure_backlook(80)
          record << cshelper.avg_close(80)
        else
          record << nil
        end
        if cshelper.ensure_backlook(100)
          record << cshelper.avg_close(100)
        else
          record << nil
        end

        csv << record
      end
    end
  end

#def process(ltcmarkets, btcmarkets)
#  ltc_x_btc = btcmarkets['LTC']
#  ltcmarkets.each do |key, value|
#    curr_x_ltc = value
#    curr_x_btc = btcmarkets[key]
#    unless curr_x_btc
#      puts "Related #{key}/BTC market does not exists"
#    else
#      puts "Processing #{key}/LTC markets"
#      result_raw = 1.01/curr_x_btc['buyprice']*curr_x_ltc['sellprice']*ltc_x_btc['buyprice'];
#      result_real = result_raw * 0.998 ** 3 # result * 3 times cryptsy transaction fee = 0.2%
#      if result_real > 1.0
#        color = ANSI.reset
#        puts sprintf(color+"Resulting earning for #{key}/LTC: %0.3f%% (without fees: %0.3f%%)"+ANSI.reset, result_real*100-100, result_raw*100-100)
#        puts sprintf(color+"1BTC => #{key}/BTC (B:%0.10f|S:%0.10f) => #{key}/LTC (B:%0.10f|S:%0.10f) => LTC/BTC (B:%0.10f|S:%0.10f)"+ANSI.reset,
#                     curr_x_btc['buyprice'], curr_x_btc['sellprice'], curr_x_ltc['buyprice'], curr_x_ltc['sellprice'], ltc_x_btc['buyprice'], ltc_x_btc['sellprice'])
#      end
#    end
#  end
#end

  private
  def do_request(response_key = 'return')
    response = yield
    if response['success'] != 1.to_s || response['error']
      raise (response['error'] || 'Some network error')
    else
      return response[response_key]
    end
  end

  def format_price(price)
    sprintf '%.8f', price
  end

  def format_dt(datetime)
    datetime.strftime "%Y-%m-%d %H:%M:%S"
  end


end
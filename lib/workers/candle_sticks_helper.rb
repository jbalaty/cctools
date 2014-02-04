class CandleSticksHelper
  def initialize(candlesticks)
    @data = candlesticks
  end

  def ensure_backlook(lenght)
    @data.length > lenght
  end

  def last(index = 0)
    get_last_element(index)
  end

  def direction(index = 0)
    get_last_element(index)[:direction]
  end

  def open(index = 0)
    get_last_element(index)[:open]
  end

  def close(index = 0)
    get_last_element(index)[:close]
  end

  def high(index = 0)
    get_last_element(index)[:high]
  end

  def low(index = 0)
    get_last_element(index)[:low]
  end

  def buy_high(index = 0)
    get_last_element(index)[:buy_high]
  end

  def buy_low(index = 0)
    get_last_element(index)[:buy_low]
  end

  def sell_high(index = 0)
    get_last_element(index)[:sell_high]
  end

  def sell_low(index = 0)
    get_last_element(index)[:sell_low]
  end

  def quantity(index = 0)
    get_last_element(index)[:quantity]
  end

  def avg_open(num_elements_back = nil)
    avg get_last_elements(num_elements_back).get_field(:open)
  end

  def avg_close(num_elements_back = nil)
    avg get_last_elements(num_elements_back).get_field(:close)
  end

  def min_open(num_elements_back = nil)
    get_last_elements(num_elements_back).get_field(:open).min
  end

  def min_close(num_elements_back = nil)
    get_last_elements(num_elements_back).get_field(:close).min
  end

  def max_open(num_elements_back = nil)
    get_last_elements(num_elements_back).get_field(:open).max
  end

  def max_close(num_elements_back = nil)
    get_last_elements(num_elements_back).get_field(:close).max
  end

  def get_field(symbol)
    @data.map { |i| i[symbol] }
  end

  def previous_step_state(num_steps_backwards = 1)
    CandleSticksHelper.new(@data.slice(0, @data.length-1))
  end


  #experimental
  def are_dir_up(from, to)
    elements = get_last_elements_range(from, to)
    elements.count { |i| i[:direction] == 'up' } == elements.length
  end

  def are_dir_down(from, to)
    elements = get_last_elements_range(from, to)
    elements.count { |i| i[:direction] == 'down' } == elements.length
  end

  def are_dir_none(from, to)
    elements = get_last_elements_range(from, to)
    elements.count { |i| i[:direction] == '-' } == elements.length
  end

  private
  def get_last_element(index)
    if index == 0
      return @data.last
    elsif index > 0
      return @data[-(index+1)]
    else
      raise "Index should be >= 0 and was #{index}"
    end
  end

  def get_last_elements_range(from, to)
    @data[-from, -to]
  end

  def get_last_elements(num_elements_back = nil)
    num_elements_back ||= @data.length
    CandleSticksHelper.new @data.slice(@data.length-num_elements_back, num_elements_back)
  end

  def avg(arr)
    arr.inject(0.0) { |sum, el| sum + el } / arr.size
  end
end
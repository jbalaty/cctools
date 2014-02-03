class GlobalValues < ActiveRecord::Base

  def get_datetime
    return Time.parse value
  end
end

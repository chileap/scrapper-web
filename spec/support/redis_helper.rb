module RedisHelper
  def clear_redis
    Redis.new.flushdb
  end
end

RSpec.configure do |config|
  config.include RedisHelper

  config.before(:each) do
    clear_redis
  end
end
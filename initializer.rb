require 'rollbar'

unless ENV['RACK_ENV']=='testing'
  Rollbar.configure do |c|
    c.access_token = ENV["ROLLBAR_ACCESS_TOKEN"]
    c.endpoint = ENV["ROLLBAR_ENDPOINT"]
    c.exception_level_filters.merge!('SignalException' => 'ignore')
  end
end

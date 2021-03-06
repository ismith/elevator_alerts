require 'rollbar'
require 'rollbar/request_data_extractor'

unless ENV['RACK_ENV']=='testing' || ENV['NO_ROLL']
  Rollbar.configure do |c|
    c.access_token = ENV["ROLLBAR_ACCESS_TOKEN"]
    c.endpoint = ENV["ROLLBAR_ENDPOINT"]
    c.exception_level_filters.merge!('SignalException' => 'ignore',
                                     'Sinatra::NotFound' => 'ignore',
                                     'Interrupt' => 'ignore')
  end
end

class RequestDataExtractor
  include Rollbar::RequestDataExtractor
  def from_rack(env)
    extract_request_data_from_rack(env).merge({
      :route => env["PATH_INFO"]
    })
  end
end

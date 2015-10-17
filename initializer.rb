require 'rollbar'

Rollbar.configure do |c|
  c.access_token = ENV["ROLLBAR_ACCESS_TOKEN"]
  c.endpoint = ENV["ROLLBAR_ENDPOINT"]
end

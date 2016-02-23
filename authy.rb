require 'faraday'
require 'json'

class Authy
  START_ENDPOINT  = "https://api.authy.com/protected/json/phones/verification/start".freeze
  VERIFY_ENDPOINT = "https://api.authy.com/protected/json/phones/verification/check".freeze

  def self.submit_number(number)
    connection = Faraday.new(:url => START_ENDPOINT)
    raw_resp = connection.post do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        :api_key => ENV['AUTHY_API_KEY'],
        :via => 'sms',
        :country_code => 1,
        :phone_number => number,
        :locale => 'en'
      }.to_json
    end
    resp = JSON.parse(raw_resp.body)

    unless resp['success']
      puts "Authy submit error: #{resp}"
    end

    return resp['success']
  end

  def self.verify_number(number, verification_code)
    connection = Faraday.new(:url => VERIFY_ENDPOINT)
    raw_resp = connection.get do |req|
      req.body = {
        :api_key => ENV['AUTHY_API_KEY'],
        :phone_number => number,
        :country_code => 1,
        :verification_code => verification_code
      }
    end

    case raw_resp.status
    when 200
      return true
    else
      puts "Authy verify error: #{raw_resp.body}"
      return false
    end
  end
end

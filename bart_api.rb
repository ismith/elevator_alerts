require 'faraday'
require 'nokogiri'

require 'models'
require 'alert'

BART_ENDPOINT = 'http://api.bart.gov/api/bsa.aspx?cmd=elev&key=MW9S-E7SL-26DU-VV8V'.freeze

class BartApi
  def self.get_data
    response = Faraday.get(BART_ENDPOINT)
    body = Nokogiri::XML(r.body)
    description = body.xpath('//bsa/description')

    if description.nil?
      Models::Unparsable.create(:data => response)
      return nil
    end

    str = description.gsub(/<\/?description>/, '')
                     .sub(/<!\[CDATA\[/, '')
                     .sub(/\]\]>/, '')
                     .strip

    alert = Alert.new(str)

    # Check for new elevators
    # Create outage objects
    # Notifications
  end
end

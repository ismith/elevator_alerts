require 'faraday'
require 'nokogiri'

require 'models'

class MuniApiError < StandardError; end

class MuniApi # SF Muni
  MUNI_ENDPOINT = 'http://webservices.nextbus.com/service/publicXMLFeed?command=messages&a=sf-muni'.freeze

  def self.get_data
    begin
      response = Faraday.get(MUNI_ENDPOINT).body
    rescue StandardError => e
      raise MuniApiError, "ERROR: #{e.class}: #{e.message}"
    end

    xml = Nokogiri::XML.parse(response)

    messages = xml.xpath('//text').to_a
                  .map { |e| e.to_s
                              .gsub(/<.?text>/, '')
                              .gsub(/\s+/, ' ') }
                  .uniq
                  .select {|s| s =~ /levator/ }
                  .reject {|s| s =~ /levator OK/ }

    elevator_names = []
    messages.each do |msg|
      e = msg.sub(/No Elevator at/, '')
             .sub(/ Station/, '')
             .sub(/ Sta\.$/, '')
      if e && e != ''
        elevator_names << "Muni: #{e}".gsub(/\s+/, ' ')
      else
        Models::Unparseable.first_or_create(:data => msg)
      end
    end

    elevator_names
  end
end

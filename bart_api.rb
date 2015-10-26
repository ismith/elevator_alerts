require 'faraday'
require 'nokogiri'

require 'models'

class BartApi
  BART_ENDPOINT = 'http://api.bart.gov/api/bsa.aspx?cmd=elev&key=MW9S-E7SL-26DU-VV8V'.freeze

  # Hit the BART_ENDPOINT, return the salient string
  def self.get_data
    response = Faraday.get(BART_ENDPOINT)
    body = Nokogiri::XML(response.body)
    description = body.xpath('//bsa/description') rescue nil

    if ( response.status != 200 ||
         description.nil? ||
         description.empty? )
      Models::Unparseable.first_or_create(:data => response.body, :status_code => response.status)
      return nil
    end

    str = description.to_s
                     .gsub(/<\/?description>/, '')
                     .sub(/<!\[CDATA\[/, '')
                     .sub(/\]\]>/, '')
                     .gsub(/  */, ' ')
                     .gsub(%r{\.}, '')
                     .gsub(/#/, '')
                     .strip
  end

  MATCH_SINGLE = %r{There is (one) elevator out of service at this time: (.*)\.?$}.freeze
  MATCH_MULTIPLE = %r{There are ([^ ]*) elevators out of service at this time: (.*)\.?$}.freeze
  MATCH_NONE = [
    %r{There are no elevators out of service at this time},
    %r{Attention passengers: All elevators are in service Thank You}
  ].freeze
  SPLIT = %r{( and |, )}.freeze

  # Given a string matching one of the three regexes above (MATCH_NONE,
  # MATCH_SINGLE, MATCH_MULTIPLE), return an array of elevator names which are
  # currently out of service.  On failure to match, store a Models::Unparseable
  # and raise a ParseError
  def self.parse_data(data)
    raise ArgumentError unless data.is_a? String
    data.gsub!(/ *Thank you.*/, '')
    data.strip!
    data.sub!(/\.$/, '')

    elevator_strings = case data
    when MATCH_NONE
      return []
    when MATCH_SINGLE
      return [ data.match(MATCH_SINGLE)[2] ]
    when MATCH_MULTIPLE
      return data.match(MATCH_MULTIPLE)[2].split(SPLIT)
                                          .reject { |s| s =~ SPLIT }
    else
      Models::Unparseable.first_or_create(:data => data)
      return []
    end
  end

  def self.run!
    data = self.get_data
    elevators = self.parse_data(data)

    puts "Currently out of service: #{elevators.join(', ')}."

    return true
  end
end

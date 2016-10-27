require 'faraday'
require 'nokogiri'

require 'models'

class BartApiError < StandardError; end
class BartApi
  BART_ENDPOINT = 'http://api.bart.gov/api/bsa.aspx?cmd=elev&key=MW9S-E7SL-26DU-VV8V'.freeze

  # Hit the BART_ENDPOINT, return the salient string
  def self.get_data
    begin
      response = Faraday.get(BART_ENDPOINT)
    rescue StandardError => e
      raise BartApiError, "ERROR: #{e.class}: #{e.message}"
    end

    body = Nokogiri::XML(response.body)
    description = body.xpath('//bsa/description') rescue nil

    if ( response.status != 200 ||
         description.nil? ||
         description.empty? )
      puts "UNPARSEABLE: #{response.status}, #{response.body}"
      if response.body.size > 254
        data = "large body: #{response.body.size}"
      else
        data = response.body.size
      end
      Models::Unparseable.first_or_create(:data => data, :status_code => response.status.to_i)

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

  MATCH_SINGLE = [
    %r{There is (one) elevator out of service at this time: (.*)\.?$},
    %r{The elevator at (.*) is out of service$}
  ].freeze
  MATCH_MULTIPLE = [
    %r{There are ([^ ]*) elevators out of service at this time: (.*)\.?$},
    %r{The following elevators are out of service: (.*)}
  ].freeze
  MATCH_NONE = [
    %r{There are no elevators out of service at this time},
    %r{Attention passengers: All elevators are in service Thank You}
    # Note: string-of-spaces case is handled in .parse_data
  ].freeze
  SPLIT = %r{( and |, )}.freeze

  # Given a string matching one of the three regexes above (MATCH_NONE,
  # MATCH_SINGLE, MATCH_MULTIPLE), return an array of elevator names which are
  # currently out of service.  On failure to match, store a Models::Unparseable
  # and raise a ParseError
  def self.parse_data(data)
    raise ArgumentError unless data.is_a? String

    return [] if data =~ %r{^  *$} # empty string -> all in service

    data.gsub!(/ *Thank you.*/, '')
    data.strip!
    data.sub!(/\.$/, '')

    # This could use some clean up
    elevator_strings = case data
    when *MATCH_NONE
      return []
    when MATCH_SINGLE[0]
      [ data.match(MATCH_SINGLE[0])[2] ]
    when MATCH_SINGLE[1]
      [ data.match(MATCH_SINGLE[1])[1] ]
    when MATCH_MULTIPLE[0]
      data.match(MATCH_MULTIPLE[0])[2].split(SPLIT)
                                             .reject { |s| s =~ SPLIT }
    when MATCH_MULTIPLE[1]
      data.match(MATCH_MULTIPLE[1])[1].split(SPLIT)
                                             .reject { |s| s =~ SPLIT }
    else
      Models::Unparseable.first_or_create(:data => data)
      return []
    end

    elevator_strings.map {|s| self.elevator_normalizer(s) }
  end

  # This could also use cleanup - maybe an inverted hash?  Or more regex?
  def self.elevator_normalizer(str)
    if ["Bayfair (platform)", "Bayfair platform elevator"].include?(str)
      "Bay Fair Platform Elevator"
    elsif str == "Pleasant Hill (Bay point platform)"
      "Pleasant Hill Bay Point Platform Elevator"
    elsif str == "ElCerritto Plaza (San Francisco/Fremont platform)"
      "El Cerrito Plaza SF/Fremont Platform Elevator"
    else
      str
    end
  end

  def self.run!
    data = self.get_data
    elevators = self.parse_data(data)

    puts "Currently out of service: #{elevators.join(', ')}."

    return true
  end
end

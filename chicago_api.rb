require 'faraday'
require 'nokogiri'

require 'models'

class ChicagoApiError < StandardError; end

class ChicagoApi # Chicago
  CHICAGO_ENDPOINT = 'http://www.transitchicago.com/travel_information/accessibility_status.aspx'.freeze

  def self.get_data
    begin
      response = Faraday.get(CHICAGO_ENDPOINT).body
    rescue StandardError => e
      raise ChicagoApiError, "ERROR: #{e.class}: #{e.message}"
    end

    html = Nokogiri::HTML.parse(response) do |config|
      config.strict.noblanks
    end

    messages = html.xpath('//a[@class="bold padrt"]').to_a.map(&:text)
    # ["Roosevelt Street-to-Mezzanine Elevator Out of Service", "Western Kimball-bound Platform Elevator Out of Service", "Elevator at 18th Temporarily Out-of-Service"]
    long_desc = html.xpath('//div[@class="col500"]/text()[preceding::div[@class="planned"] and following::div[@class="alertdate"]]').to_a.map{|e| e.text.strip}.reject(&:empty?)
    # ["Red Line - The street-to-mezzanine elevator at the Roosevelt subway station will be temporarily out of service.", "Brown Line - The Kimball-bound platform elevator at the Western station will be temporarily out of service.", "The elevator to the 54th/Cermak-bound platform at 18th (Pink Line) is temporarily out-of-service."]

    elevator_names = []
    cta_lines = %w(Red Blue Brown Green Orange Purple Pink Yellow)

    messages.zip(long_desc).each do |msg, desc|
      e = msg.sub(/(?:Temporarily )?Out.of.Service/i, '')
             .sub(/Elevator at/i, '')
             .sub(/Street.to.Mezzanine/i, '')
             .sub(/Elevator/i, '')
             .strip
      cta_line = (desc.downcase.split(/\W+/) & cta_lines.map(&:downcase))[0]
      cta_line = " #{cta_line.capitalize}" if cta_line
      if e && e != ''
        elevator_names << "Chicago#{cta_line}: #{e}".gsub(/\s+/, ' ')
      else
        Models::Unparseable.first_or_create(:data => msg)
      end
    end

    elevator_names
  end
end

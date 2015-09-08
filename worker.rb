require 'models'
require 'bart_api'

class BartWorker
  def self.run!
    # Get data
    out_elevators = BartApi.parse_data(BartApi.get_data).map do |name|
      Models::Elevators.first_or_create(:name => elevator.name)
    end

    # End outages that are over
    outages_to_end = Models::Outage.all(:ended_at => nil,
                                        :elevator.not => out_elevators)
    outages_to_end.each(&:end!)

    # Open outaages that need opening
    out_elevators.select do |e|
      Models::Outage.first(:ended_at => nil,
                           :elevator => e).nil?
    end.map do |e|
      Models::Outage.create(:elevator => e)
    end
  end
end

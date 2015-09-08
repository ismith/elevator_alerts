#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__)

require 'models'
require 'bart_api'

class BartWorker
  def self.run!
    # Get data

    existing_count = Models::Elevator.count
    data = BartApi.get_data
    out_elevators = BartApi.parse_data(data).map do |name|
      Models::Elevator.first_or_create(:name => name)
    end
    total_count = Models::Elevator.count

    puts "New elevators: #{total_count - existing_count}."
    puts "Data: #{data}"

#    # End outages that are over
#    outages_to_end = Models::Outage.all(:ended_at => nil,
#                                        :elevator.not => out_elevators)
#    outages_to_end.each(&:end!)
#
#    # Open outaages that need opening
#    out_elevators.select do |e|
#      Models::Outage.first(:ended_at => nil,
#                           :elevator => e).nil?
#    end.map do |e|
#      Models::Outage.create(:elevator => e)
#    end
  end
end

if __FILE__ == $0
  Models.setup
  BartWorker.run!
end

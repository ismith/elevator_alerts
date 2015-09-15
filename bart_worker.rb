#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__)

require 'models'
require 'bart_api'
require 'notifier'

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

    outages_to_notify = []

    # End outages that are over
    outages_to_end = Models::Outage.all_open(:elevator.not => out_elevators)
    outages_to_end.each(&:end!)
    outages_to_notify = outages_to_end

    # Open outaages that need opening
    out_elevators.reject do |e|
      Models::Outage.first(:ended_at => nil,
                           :elevator => e)
    end.map do |e|
      outage = Models::Outage.create(:elevator => e)

      outages_to_notify << outage
    end

    # Not sure why #to_a is necessary here, but: "undefined method `source_key'
    # for nil:NilClass"
    elevators_to_notify = outages_to_notify.to_a.map(&:elevator).uniq

    Notifier.send_elevator_notifications!(elevators_to_notify)
  end
end

if __FILE__ == $0
  Models.setup
  BartWorker.run!
end

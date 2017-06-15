#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__)

require 'models'
require 'bart_api'
require 'muni_api'
require 'chicago_api'
require 'notifier'
require 'my_rollbar'

# BART's API is now making state changes not from A -> B, but from A -> {} -> B,
# which means you get a sequence of:
# 1) "X, Y, Z out of service"
# 2) "All in service"
# 3) "X, Y, Z out of service"
#
# So, now, if $bart_all_working was true before, and is true now, then we update
# outage status (and send notifications).  If it was false before, we skip - it
# may be a fluke.
$bart_all_working = false

class Worker
  def self.run!
    #Keen.publish("bartworker_run", {})
    # Get data

    existing_count = Models::Elevator.count

    # BART
    bart_data = BartApi.get_data
    raw_out_elevators = BartApi.parse_data(bart_data).map do |name|
      Models::Elevator.first_or_create(:name => name)
    end

    # Any elevators that are aren't aliases - that is, alias_id is nil - are in
    # the out_elevators set
    out_elevators = raw_out_elevators.reject(&:alias_id)

    # Add the 'original' for any elevators that have an alias_id
    out_elevators += raw_out_elevators.select(&:alias_id)
      .map {|raw_e| Models::Elevator.first(:id => raw_e.alias_id) }

    out_elevators.uniq!

    # Muni - not handling alias code here because:
    # - unlike BART, we haven't needed it yet, and
    # - it's a bit of an ugly hack
    muni_data = MuniApi.get_data
    out_elevators += muni_data.map do |name|
      Models::Elevator.first_or_create(:name => name)
    end

    # Chicago
    chicago_data = ChicagoApi.get_data
    out_elevators += chicago_data.map do |name|
      Models::Elevator.first_or_create(:name => name)
    end

    total_count = Models::Elevator.count

    puts "New elevators: #{total_count - existing_count}."
    puts "Data: #{bart_data}, #{muni_data}", "#{chicago_data}"

    outages_to_notify = []

    # End outages that are over
    # Conditional is here because all(:foo.not => []) doesn't do the intuitively
    # obvious thing
    if out_elevators.empty? && $bart_all_working == false
      puts "SKIPPING NOTIFICATIONS BECAUSE $bart_all_working == false"
      # Flag that our last state was "everything working", and next time (if
      # that's still true) we'll update the DB and send notifications)
      $bart_all_working = true
      return
    elsif out_elevators.empty? && $bart_all_working == true
      puts "NOT SKIPPING NOTIFICATIONS BECAUSE $bart_all_working == true"
      outages_to_end = Models::Outage.all_open
    else
      puts "Setting $bart_all_working = false if it wasn't already"
      $bart_all_working = false
      outages_to_end = Models::Outage.all_open(:elevator.not => out_elevators)
    end
    outages_to_end.each(&:end!)
    outages_to_notify = outages_to_end

    # Open outages that need opening
    out_elevators.reject do |e|
      Models::Outage.first(:ended_at => nil,
                           :elevator => e)
    end.map do |e|
      #Keen.publish("new_outage", :elevator => e.name)
      outage = Models::Outage.create(:elevator => e)

      outages_to_notify << outage
    end

    # Not sure why #to_a is necessary here, but: "undefined method `source_key'
    # for nil:NilClass"
    elevators_to_notify = outages_to_notify.to_a.map(&:elevator).uniq

    puts "Elevators to notify: #{elevators_to_notify.size}."
    Notifier.send_elevator_notifications!(elevators_to_notify) unless elevators_to_notify.empty?
  end
end

if __FILE__ == $0
  Models.setup
  Worker.run!
end

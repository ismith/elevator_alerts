#!/usr/bin/env ruby

$LOAD_PATH.unshift File.dirname(__FILE__) + '/../'

require 'config'
require 'models'
require 'bart_api'

Models.setup

#bart = Models::System.first_or_create(:name => 'BART')

stations_file = File.dirname(__FILE__) + '/stations.dat'
File.readlines(stations_file).each do |station|
  station = Models::Station.first_or_create(:name => station.strip)

  #if station.systems.empty?
  #  station.systems = [bart]
  #  station.save
  #end
end

File.readlines(File.dirname(__FILE__) + '/elevators.dat').each do |line|
  # Not sure why the "no elevators" line causes it to barf, but this fixes it
  line = line.encode("UTF-8", :invalid => :replace, :replace => '').strip
  elevators = BartApi.parse_data(line)
  elevators.each do |e|
    Models::Elevator.first_or_create(:name => e)
  end
end

puts "DB now contains #{Models::Station.count} stations and #{Models::Elevator.count} elevators."

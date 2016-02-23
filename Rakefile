#!/usr/bin/env ruby

require 'rspec/core/rake_task'

if ENV['DOTENV'] # Not needed if we have heroku/heroku local
  require 'dotenv'
  Dotenv.load
end

$stdout.sync = true

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))

require 'rake'

desc "Pry console"
task :console do
  require 'pry'

  require 'models'
  require 'bart_api'
  require 'my_rollbar'
  require 'keen'

  Models.setup

  Pry.start
end

desc "Run worker every 60 seconds"
task :worker do
  require 'worker'
  require 'models'
  require 'my_rollbar'
  require 'keen'

  Models.setup

  loop do
    begin
      puts "Start loop ..."
      Worker.run!
      puts "About to sleep ..."
    rescue StandardError => e
      puts "ERROR: #{e.class}, #{e.message}, #{e.backtrace}"
      Rollbar.error(e)
    end

    sleep 60
  end
end

desc "Get current state"
task :current do
  require'models'
  require 'my_rollbar'
  require 'keen'
  Models.setup

  puts "Worker count: #{Models::Metric.first(:name => "bartworker").counter}"
  puts "Current outages: #{Models::Outage.all_open.count}, #{Models::Outage.all_open.to_a.map(&:elevator).map(&:name).join(", ")}"
  puts "Unparseables: #{Models::Unparseable.count}"
  puts "Users: #{Models::User.count}"
end

namespace :migrations do
  desc "Add Muni"
  task :m_001_add_muni do
    require 'models'
    require 'my_rollbar'
    Models.setup

    orig_adding_elevators = ENV['ADDING_ELEVATORS']
    ENV['ADDING_ELEVATORS'] = '1'

    if Models::System.first(:name => "SF Muni")
      puts "You already added the SF Muni system!"
      exit 1
    end

    bart = Models::System.first_or_create(:name => "BART")
    Models::Station.all.each do |s|
      next unless s.systems.empty?
      s.systems << bart
      s.save
    end
    muni = Models::System.first_or_create(:name => "SF Muni")

    ["Castro", "Church", "Civic Center", "Embarcadero", "Forest Hill",
"Montgomery", "Powell", "Van Ness", "West Portal"].each do |name|
      station = Models::Station.create(:name => "Muni: #{name}", :systems => [muni])
      elevator = Models::Elevator.create(:name => "Muni: #{name}", :station => station)
    end

    ENV['ADDING_ELEVATORS'] = orig_adding_elevators
  end

  desc "Remove ' Station' from elevator names"
  task :m_002_remove_station_from_elevator_names do
    require 'models'
    require 'my_rollbar'
    Models.setup

    Models::Elevator.all(:name.like => "Station").each do |e|
      e.name.gsub!(/ Station/, '')
      e.save
    end
  end
end

RSpec::Core::RakeTask.new(:spec) {|t| }
task :default => :spec

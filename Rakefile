#!/usr/bin/env ruby

require 'rspec/core/rake_task'

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
  require 'bart_worker'
  require 'models'
  require 'my_rollbar'
  require 'keen'

  Models.setup

  loop do
    begin
      puts "Start loop ..."
      BartWorker.run!
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

  puts "Bartworker count: #{Models::Metric.first(:name => "bartworker").counter}"
  puts "Current outages: #{Models::Outage.all_open.count}, #{Models::Outage.all_open.to_a.map(&:elevator).map(&:name).join(", ")}"
  puts "Unparseables: #{Models::Unparseable.count}"
  puts "Users: #{Models::User.count}"
end

RSpec::Core::RakeTask.new(:spec) {|t| }
task :default => :spec

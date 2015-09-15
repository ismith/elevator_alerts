#!/usr/bin/env ruby

require 'rake'

desc "Pry console"
task :console do

  $LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))

  require 'pry'

  require 'models'
  require 'bart_api'

  Models.setup

  Pry.start
end

desc "Run worker every 60 seconds"
task :worker do
  require 'bart_worker'

  loop do
    BartWorker.run!
    sleep 60
  end
end

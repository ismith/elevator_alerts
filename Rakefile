#!/usr/bin/env ruby

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))

require 'rake'

desc "Pry console"
task :console do
  require 'pry'

  require 'models'
  require 'bart_api'

  Models.setup

  Pry.start
end

desc "Run worker every 60 seconds"
task :worker do
  require 'bart_worker'
  require 'models'

  Models.setup

  loop do
    begin
      puts "Start loop ..."
      BartWorker.run!
      puts "About to sleep ..."
    rescue StandardError => e
      puts "ERROR: #{e.class}, #{e.message}, #{e.backtrace}"
      Email.send_admin_email!(:subject => "ATTN: elevator outages error",
        :body => "ERROR: #{e.class}, #{e.message}, #{e.backtrace}"
      )
    end

    sleep 60
  end
end

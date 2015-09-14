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

require 'configatron'

configatron.database = "sqlite://#{File.expand_path(File.dirname(__FILE__))}/elevator_alerts.db"

if ENV['RACK_ENV'] == 'testing'
  configatron.database = 'sqlite::memory:'
end

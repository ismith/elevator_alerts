require 'configatron'

configatron.database = "sqlite://#{File.expand_path(File.dirname(__FILE__))}/elevator_alerts.db"

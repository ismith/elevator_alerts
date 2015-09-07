require 'data_mapper'
require_relative './config'

DB_STRING_LENGTH=255
DataMapper::Property::String.length(DB_STRING_LENGTH)

module Models
  class Base
    def self.timestamps!
      property :created_at, DateTime,
               :required => true,
               :default => lambda { |r, p| Time.now.utc.to_datetime }
      property :updated_at, DateTime,
               :required => true,
               :default => lambda { |r, p| Time.now.utc.to_datetime }
    end
  end

  class Unparseable < Base
    include DataMapper::Resource

    property :id, Serial, :key => true
    property :data, String, :required => true
    property :status_code, Integer

    timestamps!
  end

  # TODO: an elevator may have more than one name
  class Elevator < Base
    include DataMapper::Resource

    property :id, Serial, :key => true
    property :name, String, :index => true, :unique => true

    has 1, :station
    has n, :systems, :through => :station
    has n, :outages

    def self.process_outage(name)

    end

    timestamps!
  end

  class Station < Base
    include DataMapper::Resource

    property :id, Serial, :key => true

    # TODO a station might have more than one name, e.g. BART/MUNI
    property :name, String, :index => true, :unique => true

    has n, :elevators, :constraint => :destroy
    has n, :systems

    timestamps!
  end

  class System < Base
    include DataMapper::Resource

    property :id, Serial, :key => true

    property :name, String, :index => true, :unique => true

    has n, :stations, :constraint => :destroy
    has n, :elevators, :through => :stations, :constraint => :destroy

    timestamps!
  end

  class Outage < Base
    include DataMapper::Resource

    property :id, Serial, :key => true

    has 1, :elevator
    has n, :systems, :through => :elevator

    property :started_at, DateTime,
              :required => true,
              :default => lambda { |r, p| Time.now.utc.to_datetime }

    property :ended_at, DateTime,
             :required => false,
             :index => true
  end

  def self.setup
    DataMapper.setup(:default, configatron.database)
    DataMapper::Model.raise_on_save_failure = true
    DataMapper.repository.adapter.resource_naming_convention =
      DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
    DataMapper.finalize
  end
end

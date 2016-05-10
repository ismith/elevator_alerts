require 'data_mapper'
require 'email'
require 'my_rollbar'

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

    def self.first_or_create(opts)
      first(opts) || create(opts)
    end
  end

  class Unparseable < Base
    include DataMapper::Resource

    property :id, Serial, :key => true
    property :data, String, :required => true
    property :status_code, Integer
    property :resolved, String, :required => false

    timestamps!

    after :create do |unparseable|
      #Keen.publish("create_unparseable", {})

      Rollbar.error("New unparseable created: #{unparseable.data}")
    end
  end

  # TODO: an elevator may have more than one name
  class Elevator < Base
    include DataMapper::Resource

    property :id, Serial, :key => true
    property :name, String, :index => true, :unique => true

    #has n, :systems, :through => :stations
    has n, :outages, :through => Resource
    belongs_to :station, :required => false

    has n, :users, :through => :station

    after :create do |elevator|
      #Keen.publish("create_elevator", :name => elevator.name)

      Rollbar.error("New elevator created: #{elevator.name}, #{elevator.id}") unless ENV['ADDING_ELEVATORS']
    end

    timestamps!

    def self.stationless
      all(:station => nil)
    end
  end

  class Station < Base
    include DataMapper::Resource

    property :id, Serial, :key => true

    # TODO a station might have more than one name, e.g. BART/MUNI
    property :name, String, :index => true, :unique => true

    has n, :elevators
    has n, :systems, :through => Resource
    has n, :users, :through => Resource

    timestamps!
  end

  class System < Base
    include DataMapper::Resource

    property :id, Serial, :key => true

    property :name, String, :index => true, :unique => true

    has n, :stations, :through => Resource
    has n, :elevators, :through => :stations, :constraint => :destroy

    def visible?
      self.class.visible.include?(self)
    end

    def self.visible
      all
    end

    timestamps!
  end

  class Outage < Base
    include DataMapper::Resource

    property :id, Serial, :key => true

    belongs_to :elevator
    #has n, :systems, :through => :elevator

    property :started_at, DateTime,
             :required => true,
             :default => lambda { |r, p| Time.now.utc.to_datetime }

    property :ended_at, DateTime,
             :required => false,
             :index => true

    def end!
      self.ended_at = DateTime.now
      self.save
    end

    def length
      ((ended_at || DateTime.now) - started_at).to_f*24
    end

    def self.all_open(opts={})
      all(opts.merge(:ended_at => nil))
    end

    def self.all_closed(opts={})
      all(opts.merge(:ended_at.not => nil))
    end

    # Gets all now-closed outages that were open at the specified time
    # Doesn't include any currently-open outages
    def self.all_at_time(time)
      all(:started_at.lte => time,
          :ended_at.gte => time)
    end
  end

  class Metric < Base
    include DataMapper::Resource

    property :id, Serial, :key => true
    property :name, String, :required => true, :index => true
    property :counter, Integer, :default => 0

    # This is *wildly* un-threadsafe
    def self.incr(name)
      m = Models::Metric.first_or_create(:name => name)
      m.counter += 1
      m.save
    end
  end

  class Report < Base
    include DataMapper::Resource

    property :id, Serial, :key => true
    property :problem_type, String
    property :problem, Text
    property :elevator_id, Integer
    property :station_id, Integer # optional, only needed if faregate report

    belongs_to :user

    timestamps!

    def elevator
      if elevator_id.zero?
        0
      else
        Models::Elevator.first(id: elevator_id)
      end
    end

    def elevator=(e)
      case e
      when Integer, String
        elevator_id = e
      when Models::Elevator
        elevator_id = e.id
      end
    end
  end

  class User < Base
    include DataMapper::Resource

    property :id, Serial, :key => true
    property :email, String, :index => true
    property :name, String, :required => false
    property :can_see_invisible_systems, Boolean, :default => false
    property :phone_number, String, :required => false
    property :phone_number_verified, Boolean, :default => false

    property :can_submit_reports, Boolean, :default => false

    timestamps!

    has n, :stations, :through => Resource
    has n, :elevators, :through => :stations

    def can_submit_reports
      true
    end

    def can_see_invisible_systems?
      !!can_see_invisible_systems
    end

    def use_phone_number?
      self.phone_number && self.phone_number_verified
    end

    def current_notification_address
      if self.use_phone_number?
        _, area_code, exchange, extension = self.phone_number.match(/(...)(...)(....)/).to_a
        "(#{area_code}) #{exchange}-#{extension}"
      else
        self.email
      end
    end
  end

  def self.setup
    if ENV['RACK_ENV'] == 'testing'
      ENV['DATABASE_URL'] = 'sqlite::memory:'
    end

    DataMapper.setup(:default, ENV['DATABASE_URL'])
    DataMapper::Model.raise_on_save_failure = true
    DataMapper.repository.adapter.resource_naming_convention =
      DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
    DataMapper.finalize

    DataMapper.auto_upgrade! unless ENV['RACK_ENV'] == 'testing'
  end
end

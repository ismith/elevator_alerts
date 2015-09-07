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
    property :data, String

    timestamps!
  end

  def self.setup
    DataMapper.setup(:default, configatron.database)
    DataMapper::Model.raise_on_save_failure = true
    DataMapper.repository.adapter.resource_naming_convention =
      DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
    DataMapper.finalize
  end
end

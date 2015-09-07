require 'rspec'

path = File.expand_path(File.dirname(__FILE__) + '/..')
$LOAD_PATH.unshift path

ENV['RACK_ENV']='testing'

::RSpec.configure do |c|
  c.before(:each) do
    Models.setup
    DataMapper.auto_migrate!
  end
end

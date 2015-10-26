require 'rspec'

path = File.expand_path(File.dirname(__FILE__) + '/..')
$LOAD_PATH.unshift path

ENV['RACK_ENV']='testing'

require 'pry-debugger'

require 'pony'

::RSpec.configure do |c|
  c.before(:each) do
    Models.setup
    DataMapper.auto_migrate!

    Pony.stub(:mail)

    Keen.stub(:publish)
    Rollbar.stub(:error)
    Rollbar.stub(:warn)
    Rollbar.stub(:log)
  end
end

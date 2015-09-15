require 'rspec'

path = File.expand_path(File.dirname(__FILE__) + '/..')
$LOAD_PATH.unshift path

ENV['RACK_ENV']='testing'

require 'pry-debugger'

::RSpec.configure do |c|
  c.before(:each) do
    Models.setup
    DataMapper.auto_migrate!

    Pony.stub(:mail)
  end
end

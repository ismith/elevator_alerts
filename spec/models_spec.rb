require 'spec_helper'
require 'models'

describe Models::Unparseable do
  subject { described_class.new }

  it { should respond_to :data }
end

describe Models::Elevator do
  subject { described_class.new }

  it { should respond_to :name }
  it { should respond_to :station }

  it { should respond_to :system }
end

describe Models::Station do
  subject { described_class.new }

  it { should respond_to :name }
  it { should respond_to :systems }

  it { should respond_to :elevators }
end

describe Models::System do
  subject { described_class.new }

  it { should respond_to :name }

  it { should respond_to :stations }
  it { should respond_to :elevators }
end

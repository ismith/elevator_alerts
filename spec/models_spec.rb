require 'spec_helper'
require 'models'

describe Models::Unparseable do
  subject { described_class.new }

  it { should respond_to :data }
  it { should respond_to :status_code }
end

describe Models::Elevator do
  subject { described_class.new }

  it { should respond_to :name }
  it { should respond_to :station }

  it { should respond_to :systems }

  it { should respond_to :outages }
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

describe Models::Outage do
  subject { described_class.new }

  it { should respond_to :elevator }
  it { should respond_to :started_at }
  it { should respond_to :ended_at }
  it { should respond_to :systems }

  it 'should have a default started_at value' do
    expect(subject.started_at).not_to be_nil
  end
end

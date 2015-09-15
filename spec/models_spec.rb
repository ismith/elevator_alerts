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
  it { should respond_to :users }

  #it { should respond_to :systems }

  it { should respond_to :outages }

  it 'should have an after-create hook to send the admin an email' do
    skip
  end

  describe 'class methods' do
    subject { described_class }

    it { should respond_to :stationless }
  end
end

describe Models::Station do
  subject { described_class.new }

  it { should respond_to :name }
  #it { should respond_to :systems }

  it { should respond_to :elevators }
  it { should respond_to :users }
end

#describe Models::System do
#  subject { described_class.new }
#
#  it { should respond_to :name }
#
#  it { should respond_to :stations }
#  it { should respond_to :elevators }
#end

describe Models::Outage do
  subject { described_class.new }

  it { should respond_to :elevator }
  it { should respond_to :started_at }
  it { should respond_to :ended_at }
  #it { should respond_to :systems }

  it 'should have a default started_at value' do
    expect(subject.started_at).not_to be_nil
  end

  describe '#end!' do
    subject { outage.end! }

    let(:outage) { described_class.new(:elevator => elevator) }
    let(:elevator) { Models::Elevator.first_or_create(:name => SecureRandom.hex) }

    it 'should set an ended_at on the Outage' do
      expect { subject }.to change { outage.reload.ended_at }.from(nil)
                                                             .to(kind_of(DateTime))
    end
  end

  describe 'class methods' do
    subject { described_class }

    it { should respond_to :all_open }
    it { should respond_to :all_closed }
  end
end

describe Models::Metric do
  subject { described_class.new }

  it { should respond_to :name }
  it { should respond_to :counter }

  describe 'class methods' do
    subject { described_class }

    describe '.incr' do
      subject { described_class.incr(name) }

      let(:name) { SecureRandom.hex }

      context 'on first call' do
        it 'should create a new record, and set its counter to 1' do
          subject
          expect(Models::Metric.first(:name => name).counter).to be 1
        end
      end

      context 'on subsequent calls' do
        it 'should increment the counter' do
          Models::Metric.incr(name)

          expect { subject }.to change { Models::Metric.first(:name).counter }.by 1
        end
      end
    end
  end
end

describe Models::User do
  subject { described_class.new }

  it { should respond_to :email }
  it { should respond_to :elevators }
  it { should respond_to :stations }
end

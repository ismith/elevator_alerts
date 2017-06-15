require 'spec_helper'
require 'worker'

describe Worker do
  subject { described_class.run! }

  let(:predata) { ['elevator0', 'elevator1', 'elevator2'] }
  let(:bart_data) { ['elevator2', 'elevator3'] }
  let(:muni_data) { ['elevator0', 'elevator4'] }

  before :each do
    elevators = predata.map do |e|
      Models::Elevator.first_or_create(:name => e)
    end

    elevators.map do |e|
      Models::Outage.create(:started_at => DateTime.now - rand(1..3),
                            :elevator => e)
    end

    expect(Models::Outage.all_open.count).to eql predata.size

    allow(BartApi).to receive(:get_data)
    allow(BartApi).to receive(:parse_data).and_return(bart_data)
    allow(MuniApi).to receive(:get_data).and_return(muni_data)
  end

  # We end with two ended outages (elevator0, elevator2), one that remains open
  # (elevator2) and two new outages (elevator3, elevator4)
  it 'should call BartApi and MuniApi, end two of the outages, and open another 2' do
    subject

    # Not sure why the #to_a is required here
    expect(Models::Outage.all_open.to_a.map(&:elevator).map(&:name)).to match_array ( bart_data + muni_data )
    expect(Models::Outage.all_open.size).to eql ( bart_data + muni_data ).size
    expect(Models::Outage.all_closed.size).to be 1
    expect(Models::Outage.count).to be 5
  end

  # elevator1, elevator3, and elevator 4; elevator0 and elevator2 do not change state
  it 'should call Notifier.send_elevator_notifications with four elevators' do
    expect(Notifier).to receive(:send_elevator_notifications!) do |elevators|
      expect(elevators.map(&:name)).to match_array(['elevator1', 'elevator3', 'elevator4'])
    end

    subject
  end

  context 'if one of the received elevators is an alias' do
    before :each do
      orig_elevator = Models::Elevator.first_or_create(:name => 'orig_elevator')
      # We create an alias elevator; this is the one that is in our input data,
      # not the orig_elevator
      Models::Elevator.first_or_create(:name => 'alias elevator', :alias_id => orig_elevator.id)

      allow(BartApi).to receive(:get_data)
      allow(BartApi).to receive(:parse_data).and_return(bart_data)
      allow(MuniApi).to receive(:get_data).and_return(muni_data)
    end

    let(:bart_data) { ['alias elevator'] }
    let(:muni_data) { [] }
    let(:predata) { [] }

    it 'should look up the original elevator' do
      # It'll notify for the original elevator, not the alias
      expect(Notifier).to receive(:send_elevator_notifications!) do |elevators|
        expect(elevators.map(&:name)).to match_array('orig_elevator')
      end

      subject

      expect(Models::Outage.all_open.to_a.map(&:elevator).map(&:name)).to match_array('orig_elevator')
    end
  end

  context 'if there are no out elevators' do
    let(:bart_data) { [] }
    let(:muni_data) { [] }

    it "should not notify (or change DB state) the 1st or 3rd time 'all elevators are in service', but should the 2nd time" do
      expect(Notifier).to receive(:send_elevator_notifications!).once do |elevators|
        expect(elevators).not_to be_empty
      end

      # First run
      described_class.run!
      expect(Models::Outage.all_open).not_to be_empty

      # Second run
      described_class.run!
      expect(Models::Outage.all_open).to be_empty

      # Third run
      described_class.run!
      expect(Models::Outage.all_open).to be_empty
    end
  end
end

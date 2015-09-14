require 'spec_helper'
require 'worker'

describe BartWorker do
  subject { described_class.run! }

  let(:predata) { ['elevator1', 'elevator2'] }
  let(:data) { ['elevator2', 'elevator3'] }

  before :each do
    elevators = predata.map do |e|
      Models::Elevator.first_or_create(:name => e)
    end

    elevators.map do |e|
      Models::Outage.create(:started_at => DateTime.now - rand(1..3),
                            :elevator => e)
    end

    expect(Models::Outage.all_open.count).to eql predata.size
  end

  # We end with one ended outage (elevator1), one that remains open (elevator2)
  # and one new outage (elevator3)
  it 'should call BartApi, end one of the outages, and open another' do
    expect(BartApi).to receive(:get_data).and_call_original
    expect(BartApi).to receive(:parse_data).and_return(data)

    subject

    # Not sure why the #to_a is required here
    expect(Models::Outage.all_open.to_a.map(&:elevator).map(&:name)).to match_array data
    expect(Models::Outage.all_open.size).to eql data.size
    expect(Models::Outage.all_closed.size).to be 1
    expect(Models::Outage.count).to be 3
  end
end

require 'spec_helper'
require 'notifier'

describe Notifier do
  subject { described_class }

  describe '.send_elevator_notifications!' do
    # Call reload to make sure these elevator objects have picked up their
    # associated stations and users
    subject { Notifier.send_elevator_notifications!(elevators_to_notify.map(&:reload)) }

    # TODO: tests
    let!(:stations) { (0..2).map { |i| Models::Station.first_or_create(:name => "station#{i}") } }
    let!(:elevators_to_notify) { stations.map {|s| Models::Elevator.create(:name => s.name.sub(/station/, 'elevator'), :station => s) } }
    let!(:outages) { elevators_to_notify.map {|e| Models::Outage.create(:elevator => e) } }

    let!(:unchanged_elevator) { Models::Elevator.create(:name => 'unchanged elevator', :station => Models::Station.create(:name => "another station")) }
    let!(:unchanged_outage) { Models::Outage.create(:elevator => unchanged_elevator) }

    let!(:user1) do
      Models::User.create(:email => 'user1@example.com').tap do |u|
        u.stations = [ stations[0], stations[1], unchanged_elevator.station ]
        u.save
      end
    end
    let!(:user2) do
      Models::User.create(:email => 'user2@example.com').tap do |u|
        u.stations = [ stations[1], stations[2], unchanged_elevator.station ]
        u.save
      end
    end

    let!(:user3) do
      Models::User.create(:email => 'user3@example.com').tap do |u|
        u.stations = [ unchanged_elevator.station ]
        u.save
      end
    end

    before :each do
      # One of the outages should be 'ended'; the other two are open
      outages[1].end!
    end

    # Two of the users 'see' outages, one does not (because the only elevator
    # affecting it was unchanged)
    it 'should send one email per user affected' do
      expect(Email).to receive(:mail).twice
      subject
    end

    it "should include the name of all the elevators currently out, including the 'unchanged' one" do
      messages = []
      allow(Email).to receive(:mail) do |arg_hash|
        messages << arg_hash[:body]
      end

      subject

      expect(messages.join).to include(": elevator0 and unchanged elevator.")
      expect(messages.join).to include(": elevator2 and unchanged elevator.")
      expect(messages.join).not_to include("elevator1.")
    end

    context 'if all the outages are closed' do
      before :each do
        outages.each {|o| o.end!}
        unchanged_outage.end!
      end

      it 'should send email indicating that' do
        expect(Email).to receive(:mail).twice do |arg_hash|
          expect(arg_hash[:body]).to match /All of your elevators are currently in service./
        end

        subject
      end
    end
  end

  describe '.elevator_notification_message' do
    subject { described_class.elevator_notification_message(elevators) }

    context 'with no outages' do
      let(:elevators) { [] }

      it { should be_a String }
    end

    context 'with one outage' do
      let(:elevators) { ['elevator1'] }

      it { should be_a String }
    end

    context 'with n>1 outages' do
      let(:elevators) { ['elevator1', 'elevator2'] }

      it { should be_a String }
    end
  end
end

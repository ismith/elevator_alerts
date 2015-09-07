require 'spec_helper'

require 'bart_api'

describe BartApi do
  describe '.get_data' do
    subject { described_class.get_data }

    let(:mock_faraday_response) { double("mock FaradayResponse", :status => status,
                                                                 :body => body) }
    before :each do
      allow(Faraday).to receive(:get).and_return(mock_faraday_response)
    end

    context 'if it responds as expected' do
      let(:status) { 200 }
      let(:body) { "<?xml version=\"1.0\" encoding=\"utf-8\"?><root><uri><![CDATA[http://api.bart.gov/api/bsa.aspx?cmd=elev]]></uri><date>09/07/2015</date>\n<time>14:22:00 PM PDT</time>\n<bsa id=\"135806\">\n<station>BART</station>\n<type>ELEVATOR</type>\n<description><![CDATA[There is one elevator out of service at this time:  Ashby Street Elevator.  Thank you.  ]]></description>\n<sms_text><![CDATA[1 elev out of svc  ASBY st elev.]]></sms_text>\n<posted>Sun Sep 06 2015 08:54 PM PDT</posted>\n<expires></expires>\n</bsa>\n<message></message></root>" }

      it { should be_a String }
      it { should =~ /one elevator out of service at this time: Ashby Street Elevator/ }
    end

    context 'if it responds with a non-200' do
      let(:status) { 400 }
      let(:body) { 'some body' }

      it { should be_nil }

      it 'should save the unparseable body' do
        expect { subject }.to change { Models::Unparseable.count }.by 1
        expect(Models::Unparseable.last.data).to eql body
        expect(Models::Unparseable.last.status_code).to eql status
      end
    end

    context 'if it responds with a 200 and an unparseable body' do
      let(:status) { 200 }
      let(:body) { 'some body' }

      it { should be_nil }

      it 'should save the unparseable body' do
        expect { subject }.to change { Models::Unparseable.count }.by 1
        expect(Models::Unparseable.last.data).to eql body
        expect(Models::Unparseable.last.status_code).to eql status
      end
    end
  end

  describe '.parse_data' do
    subject { described_class.parse_data(input) }

    context 'with unparseable input' do
      let(:input) { "Bad input lol" }

      it 'should save the data and raise a ParseError' do
        expect(Models::Unparseable.count).to be 0
        expect { subject }.to raise_error(ParseError)
        expect(Models::Unparseable.count).to be 1
      end
    end

    context 'with no elevators' do
      let(:input) { 'There are no elevators out of service at this time.' }

      it { should be_a Array }
      it { should be_empty }
    end

    context 'with one elevator' do
      let(:input) { 'There is one elevator out of service at this time: Ashby Street Elevator. Thank you.' }

      it { should be_a Array }
      it { should match_array ['Ashby Street Elevator'] }
    end

    context 'with three elevators' do
      let(:input) { 'There are three elevators out of service at this time: 12th St. Oakland Ogawa Plaza Elevator, El Cerrito Plaza S.F./Fremont Platform Elevator and Coliseum Platform Elevator.' }

      it { should be_a Array }

      it { should match_array ['12th St. Oakland Ogawa Plaza Elevator', 'El Cerrito Plaza S.F./Fremont Platform Elevator', 'Coliseum Platform Elevator' ] }
    end

    context 'all in data/elevators.dat' do
      it 'should be able to parse them' do
        lines = File.readlines(File.expand_path(File.dirname(__FILE__) + '/../data/elevators.dat')).map(&:chomp)
        failures = lines.map do |line|
          described_class.parse_data(line) rescue line
        end.reject { |x| x.is_a? Array }

        expect(failures).to be_empty
      end
    end
  end
end

require 'spec_helper'
require 'email'

describe Email do
  subject { Email.mail(opts) }

  describe '.mail' do
    let(:opts) do
      { :to => 'some-to-address', :subject => 'some subject', :body => 'some body' }
    end

    it 'should send email using Pony' do
      expect(Pony).to receive(:mail)
      subject
    end
  end
end

require 'twilio-ruby'

class MyTwilio
  def self.client
    Twilio::REST::Client.new(ENV['TWILIO_ACCOUNT_SID'],
                             ENV['TWILIO_AUTH_TOKEN'])
  end

  def self.send_sms(opts = {})
    to = opts.fetch(:to)
    body = opts.fetch(:body)
    from = ENV['TWILIO_FROM_NUMBER']

    client.messages.create(:to => to,
                           :from => from,
                           :body => body)
  end
end

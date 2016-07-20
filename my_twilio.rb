require 'twilio-ruby'

class MyTwilio
  def self.client
    if ENV['TWILIO_ACCOUNT_SID'] && ENV['TWILIO_AUTH_TOKEN']
      Twilio::REST::Client.new(ENV['TWILIO_ACCOUNT_SID'],
                              ENV['TWILIO_AUTH_TOKEN'])
    else
      nil
    end
  end

  def self.send_sms(opts = {})
    to = opts.fetch(:to)
    body = opts.fetch(:body)

    if client.nil?
      warn "Twilio not configured, or we'd send '#{body}' to #{to}."
    end

    from = ENV['TWILIO_FROM_NUMBER']

    client.messages.create(:to => to,
                           :from => from,
                           :body => body)
  end
end

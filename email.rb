require 'net/smtp'

if ENV['RACK_ENV'] == 'testing' || ENV['RACK_ENV'] == 'development'
  require 'json'
  require 'faraday'

  mailtrap_response = Faraday.get("https://mailtrap.io/api/v1/inboxes.json?api_token=#{ENV['MAILTRAP_API_TOKEN']}")
  first_inbox = JSON.parse(mailtrap_response.body)[0]

  # first_inbox is a hash containing 'username', 'password', 'domain, 'smtp_ports'
  SERVER = 'mailtrap.io'
  PORT = 2525
  HELO = 'mailtrap.io'
  USERNAME = ENV['MAILTRAP_USERNAME']
  PASSWORD = ENV['MAILTRAP_PASSWORD']
else
  SERVER = 'smtp.sendgrid.com'
  PORT = 587
  HELO = 'smtp.sendgrid.com'
  USERNAME = ENV['SENDGRID_USERNAME']
  PASSWORD = ENV['SENDGRID_PASSWORD']
end

class Email
  def self.send!(opts = {})
    unless opts.keys.include?(:to) &&
           opts.keys.include?(:from) &&
           opts.keys.include?(:msg)
      raise ArgumentError, "Expected hash containing :to, :from, :msg, got #{opts.keys}"
    end


    msg = <<HEREDOC
From: #{opts[:from]}
To: #{opts[:to]}
Subect: #{opts[:subject] || "No subject!"}
Date: #{Time.now.utc.to_datetime.iso8601}"
Message-Id: <#{SecureRandom.uuid}@#{opts[:from].sub(/.*@/, '')}>

#{opts[:msg]}
HEREDOC

    return true if ENV['RACK_ENV'] == 'testing'

    Net::SMTP.start(SERVER, PORT, HELO, USERNAME, PASSWORD) do |smtp|
      smtp.send_message(opts[:msg], opts[:from], opts[:to])
    end
  end
end

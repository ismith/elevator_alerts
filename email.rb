require 'pony'
require 'json'

Pony.options = {
  :from => 'noreply@elevatoralerts.com',
  :via => :smtp,
  :via_options => {
    :address => 'smtp.sendgrid.net',
    :port => '587',
    :domain => 'mail.elevatoralerts.com',
    :user_name => ENV['SENDGRID_USERNAME'],
    :password => ENV['SENDGRID_PASSWORD'],
    :authentication => :plain,
    :enable_starttls_auto => true
  }
}.freeze

class Email
  def self.mail(opts = {})
    to = opts.fetch(:to)
    subject = opts.fetch(:subject)
    body = opts.fetch(:body)

    # Can't find the opentrack setting in sendgrid's web dashboard, so disable it here
    headers = { "X-SMTPAPI" => { :filters => { :opentrack => { :settings => { :enable => 0 } } } }.to_json }

    #Keen.publish("email", to: to, subject: subject)

    if ENV['NO_EMAIL']
      puts "Email is currently disabled, or we'd send: #{to}\nsubject:#{subject}\nbody:\n#{body}"
    else
      Pony.mail(:to => to, :subject => subject, :body => body, :headers => headers)
    end
  end
end

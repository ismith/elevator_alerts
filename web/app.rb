require 'rubygems'
require 'sinatra'
require 'json'
require 'rest-client'
require 'encrypted_cookie'
require 'rack-canonical-host'
require 'rack/csrf'
require 'rack-flash'

f= File.join(File.dirname(File.expand_path(__FILE__)), '..')
$LOAD_PATH.unshift f
require 'models'
require 'my_rollbar'
require 'rollbar/middleware/sinatra'
require 'keen'
require 'rack-google-analytics'

require 'notifier'

# Faster logging
$stdout.sync = true

Models.setup

use Rollbar::Middleware::Sinatra

use Rack::CanonicalHost, ENV['SESSION_DOMAIN']
domain = ENV['SESSION_DOMAIN'] unless ENV['SESSION_DOMAIN'] == 'localhost'
use Rack::Session::EncryptedCookie, :secret => ENV['SESSION_SECRET'],
                                    :domain => domain,
                                    :httponly => true
use Rack::Csrf, :skip => ['POST:/auth/login'],
                :raise => true

disable :show_exceptions

use Rack::Flash, :sweep => true

use Rack::GoogleAnalytics, :tracker => ENV['GOOGLE_ANALYTICS_KEY']

helpers do
  def login?
    !session[:email].nil?
  end

  def audience
    protocol = request.env['HTTP_X_FORWARDED_PROTO']
    port = request.env['HTTP_X_FORWARDED_PORT']

    audience = "#{protocol}://#{ENV['SESSION_DOMAIN']}:#{port}"
    puts "AUDIENCE: #{audience}"
    audience
  end

  def email_is_authorized?(email)
    return true if ENV['ALLOWED_USERS'] == '*'
    if ENV['ALLOWED_USERS'].split(',').map(&:strip).include?(email)
      puts "#{email} is an allowed user"
      return true
    else
      puts "#{email} is not an allowed user"
      return false
    end
  end

  def require_login!(msg = "Sorry, you'll need to be logged in first.")
    unless login?
      puts "ERROR: #{session.inspect}"
      flash[:notice] = msg
      redirect '/'
    end
  end
end

get "/" do
  erb :index
end

post "/auth/login" do
  # check assertion with a request to the verifier
  response = nil
  if params[:assertion]
    restclient_url = "https://verifier.login.persona.org/verify"
    restclient_params = {
      :assertion => params["assertion"],
      :audience  => audience
    }
    puts "Attempting login for #{restclient_params[:audience]}"
    response = JSON.parse(RestClient::Resource.new(restclient_url, :verify_ssl => true).post(restclient_params))
  end

  # create a session if assertion is valid
  if response["status"] == "okay" && email_is_authorized?(response["email"])
    session[:email] = response["email"]
    response.to_json
  else
    headers = Hash[*env.select {|k,v| k.start_with? 'HTTP_'}
      .collect {|k,v| [k.sub(/^HTTP_/, ''), v]}
      .sort
      .flatten]

    $stdout.puts "LOGIN ERROR: #{response.inspect}, headers: #{headers}"
    {:status => "error"}.to_json
  end
end

get "/auth/logout" do
   session[:email] = nil
   redirect "/"
end

get '/subscriptions' do
  require_login!

  @stations = Models::Station.all
  @user = Models::User.first_or_create(:email => session[:email])
  erb :subscriptions
end

post '/api/subscriptions' do
  require_login!


  @user = Models::User.first(:email => session[:email])
  original_stations = @user.stations
  @stations = Models::Station.all(:id => params[:stations])

  @user.stations = @stations

  if @user.dirty?
    @user.save &&
      flash[:notice] = 'Saved your changes!'

    # If I wanted to be clever, I could do this only if the elevators currently
    # out include ones changed in this request ... but I think it's more useful
    # not to do that; allows users to get a sample notification.
    my_outages = Models::Outage.all_open(:elevator => @user.stations.to_a.flat_map(&:elevators))
    my_out_elevators = my_outages.to_a.map(&:elevator)

    Notifier.send_user_elevator_notification!(@user, my_out_elevators)
  end

  redirect '/subscriptions'
end

# get '/test_error' do
#   raise StandardError, "test error"
#   "Hello world! <- this should never be reached"
# end

require 'rubygems'
require 'sinatra'
require 'json'
require 'rest-client'
require 'encrypted_cookie'
require 'rack-canonical-host'
require 'rack/csrf'
require 'rack-flash'

if ENV['DOTENV'] # Not needed if we have heroku/heroku local
  require 'dotenv'
  Dotenv.load
end

f= File.join(File.dirname(File.expand_path(__FILE__)), '..')
$LOAD_PATH.unshift f
require 'models'
require 'my_rollbar'
require 'rollbar/middleware/sinatra'
require 'keen'
require 'rack-google-analytics'

require 'notifier'

require 'omniauth-google-oauth2'

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

use OmniAuth::Builder do
  provider :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'],
    :scope => 'email',
    :prompt => 'select_account',
    :name => 'login'
end

helpers do
  def login?
    !session[:email].nil?
  end

  def audience
    protocol = request.env['HTTP_X_FORWARDED_PROTO']
    port = request.env['HTTP_X_FORWARDED_PORT']

    if ENV['SESSION_DOMAIN'] == 'localhost'
      audience = "#{ENV['SESSION_DOMAIN']}:#{port}"
    else
      audience = "#{protocol}://#{ENV['SESSION_DOMAIN']}:#{port}"
    end
    puts "AUDIENCE: #{audience}" if ENV['DEBUG']
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
      puts "ERROR: #{session.inspect}" if ENV['DEBUG']
      flash[:notice] = msg
      redirect '/'
    end
  end
end

get "/" do
  erb :index
end

get "/auth/logout" do
   session[:email] = nil
   redirect "/"
end

get "/auth/login/callback" do
  session[:email] = env['omniauth.auth'][:info][:email]
  session[:name] = env['omniauth.auth'][:info][:name]
  redirect "/"
end

get '/subscriptions' do
  require_login!

  @user = Models::User.first_or_create(:email => session[:email])

  if @user.can_see_invisible_systems?
    @systems = Models::System.all
  else
  @systems = Models::System.visible
  end

  @stations = @systems.flat_map(&:stations).uniq

  # If we didn't have a user's name before, save it
  if @user.name != session[:name]
    @user.name = session[:name]
    @user.save
  end

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

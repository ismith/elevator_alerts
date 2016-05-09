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
require 'rack-google-analytics'

require 'notifier'

require 'omniauth-google-oauth2'

require 'authy'

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
    :scope => 'email, openid',
    :prompt => 'select_account',
    :name => 'login'
end

helpers do
  def login?
    !session[:email].nil? &&
      @user = Models::User.first_or_create(:email => session[:email])
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

  @user = Models::User.first_or_create(:email => session[:email])

  # If we didn't have a user's name before, save it
  if @user.name != session[:name]
    @user.name = session[:name]
    @user.save
  end

  redirect "/"
end

get '/subscriptions' do
  require_login!

  if @user.can_see_invisible_systems?
    @systems = Models::System.all
  else
  @systems = Models::System.visible
  end

  @stations = @systems.flat_map(&:stations).uniq

  erb :subscriptions
end

get '/notifications' do
  require_login!

  erb :notifications
end

post '/api/notifications' do
  require_login!

  halt 412 unless @user.phone_number.nil?

  phone_number = params[:phone_number].gsub(/[^0-9]/, '')

  # If phone_number is exactly 10 digits, it is valid
  if phone_number =~ %r{\A[0-9]*\z} && phone_number.length == 10
    @user.phone_number = phone_number
    Authy.submit_number(params[:phone_number])
    @user.save
  else
    flash[:notice] = "#{params[:phone_number]} is not a valid phone number - try again."
  end

  redirect '/notifications'
end

post '/api/notifications/verify' do
  require_login!

  # Error if sms isn't in notification state

  if Authy.verify_number(@user.phone_number, params[:verification_code])
    @user.phone_number_verified = true
    @user.save
  else
    flash[:notice] = 'Incorrect verification code!'
    redirect '/notifications'
  end

  redirect '/notifications'
end

post '/api/notifications/delete' do
  require_login!

  @user.phone_number = nil
  @user.phone_number_verified = false
  @user.save

  redirect '/notifications'
end

post '/api/notifications/resend' do
  require_login!

  Authy.submit_number(@user.phone_number)

  flash[:notice] = 'Resent verification code.'

  redirect '/notifications'
end

post '/api/subscriptions' do
  require_login!

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

get '/reports' do
  require_login!

  erb :report
end

post '/api/report' do
  require_login!

  unless @user.can_submit_reports
    redirect '/'
  end

  elevator = params[:elevator]

  problem = params[:problem]
  problem_type = params[:problem_type]

  puts "REPORT: #{elevator}, #{@user.id}, #{problem_type}, #{problem}"
  unless problem_type == 'no problem'
    Rollbar.error("REPORT: #{elevator}, #{@user}, #{problem_type}, #{problem}")
  end

  Models::Report.create(
    :elevator_id => elevator, # we don't instantiate the elevator record bc it is sometimes 0 or nil
    :user => @user,
    :problem => problem,
    :problem_type => problem_type
  )

  flash[:notice] = 'Thanks for the report!'
  redirect '/reports'
end

# Only BART for now because that's where we're accepting reports
get '/api/bart/elevators.json' do
  content_type 'application/json'

  system = Models::System.first(:name => "BART")
  Hash[system.stations.map do |station|
    [station.id,
     station.elevators.map do |elevator|
       { :text => elevator.name,
         :value => elevator.id }
     end]
  end].to_json
end

# get '/test_error' do
#   raise StandardError, "test error"
#   "Hello world! <- this should never be reached"
# end

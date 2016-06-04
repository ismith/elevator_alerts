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
require 'rack-google-analytics'

require 'notifier'

require 'omniauth-google-oauth2'
require 'auth'

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

CSRF_SKIP = ['POST:/auth/login',
             'POST:/auth/developer/callback'].freeze
use Rack::Csrf, :skip => CSRF_SKIP,
                :raise => true

disable :show_exceptions

use Rack::Flash, :sweep => true

if ENV['GOOGLE_ANALYTICS_KEY']
  use Rack::GoogleAnalytics, :tracker => ENV['GOOGLE_ANALYTICS_KEY']
end

use OmniAuth::Builder do
  provider *Auth.provider_opts
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

require 'routes/auth'
require 'routes/notifications'
require 'routes/reports'
require 'routes/subscriptions'

# get '/test_error' do
#   raise StandardError, "test error"
#   "Hello world! <- this should never be reached"
# end

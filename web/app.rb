require 'rubygems'
require 'sinatra'
require 'json'
require 'rest-client'
require 'encrypted_cookie'
require 'rack-canonical-host'

class Hash
  def options
    self['options']
  end
end

f= File.join(File.dirname(File.expand_path(__FILE__)), '..')
$LOAD_PATH.unshift f
require 'models'

Models.setup

use Rack::CanonicalHost, ENV['SESSION_DOMAIN']

domain = ENV['SESSION_DOMAIN'] unless ENV['SESSION_DOMAIN'] == 'localhost'
use Rack::Session::EncryptedCookie, :secret => ENV['SESSION_SECRET'],
                                    :domain => domain,
                                    :httponly => true
disable :show_exceptions

helpers do
  def login?
    !session[:email].nil?
  end

  def session_port
    ENV['SESSION_DOMAIN'] == 'localhost' ? 4567 : 80
  end

  def email_is_authorized?(email)
    return true if ENV['ALLOWED_USERS'] == '*'
    return ENV['ALLOWED_USERS'].split(',').map(&:strip).include?(email)
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
      :audience  => "http://#{ENV['SESSION_DOMAIN']}:#{session_port}"
    }
    response = JSON.parse(RestClient::Resource.new(restclient_url, :verify_ssl => true).post(restclient_params))
  end

  # create a session if assertion is valid
  if response["status"] == "okay" && email_is_authorized?(response["email"])
    session[:email] = response["email"]
    response.to_json
  else
    {:status => "error"}.to_json
  end
end

get "/auth/logout" do
   session[:email] = nil
   redirect "/"
end

get '/subscriptions' do
  redirect '/' unless session[:email]

  @stations = Models::Station.all
  @user = Models::User.first(:email => session[:email])
  erb :subscriptions
end

post '/api/subscriptions' do
  halt 401 unless session[:email]

  @user = Models::User.first(:email => session[:email])
  @stations = Models::Station.all(:id => params[:stations])

  @user.stations = @stations
  @user.save

  redirect '/subscriptions'
end

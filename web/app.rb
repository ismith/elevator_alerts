require 'rubygems'
require 'sinatra'
require 'json'
require 'rest-client'

# This session cookie never expires.
set :session_secret, ENV['SESSION_SECRET']
set :sessions, :domain => ENV['SESSION_DOMAIN']
enable :sessions

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

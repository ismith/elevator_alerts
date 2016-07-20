if Auth.strategy == :developer
  get '/auth/login' do
    redirect '/auth/developer'
  end

  post '/auth/developer/callback' do
    instance_eval &Auth.callback_block
  end
end

get "/auth/logout" do
   session[:email] = nil
   redirect "/"
end

get "/auth/login/callback" do
  instance_eval &Auth.callback_block
end

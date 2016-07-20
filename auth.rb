class Auth
  OPTIONS_BY_STRATEGY = {
    :developer => [
      :developer,
      { :fields => [:email, :name],
        :uid_field => :email }
    ],
    :google_oauth2 => [
      :google_oauth2,
      ENV['GOOGLE_CLIENT_ID'],
      ENV['GOOGLE_CLIENT_SECRET'],
      { :scope => 'email, openid',
        :prompt => 'select_account',
        :name => 'login' }
    ]
  }

  def self.strategy
    if ENV['GOOGLE_CLIENT_ID'] && ENV['GOOGLE_CLIENT_SECRET']
      :google_oauth2
    else
      warn "USING :developer AUTH STRATEGY! This is *insecure* and should only be used on localhost. Look in the README for 'GOOGLE_CLIENT_ID' for instructions on setting this up."
      :developer
    end
  end

  def self.provider_opts
    OPTIONS_BY_STRATEGY[strategy]
  end

  def self.callback_block
    Proc.new {
      session[:email] = env['omniauth.auth'][:info][:email]
      session[:name] = env['omniauth.auth'][:info][:name]

      @user = Models::User.first_or_create(:email => session[:email])

      if @user.name != session[:name]
        @user.name = session[:name]
        @user.save
      end

      redirect '/'
    }
  end
end

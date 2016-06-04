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

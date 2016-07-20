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

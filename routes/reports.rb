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
  station = params[:station]

  problem = params[:problem]
  problem_type = params[:problem_type]

  puts "REPORT: #{elevator}, #{@user.id}, #{problem_type}, #{problem}"
  unless problem_type == 'no problem'
    Rollbar.error("REPORT: #{elevator}, #{@user.id}, #{problem_type}, #{problem}")
  end

  Models::Report.create(
    :elevator_id => elevator, # we don't instantiate the elevator record bc it is sometimes 0 or nil
    :user => @user,
    :problem => problem,
    :problem_type => problem_type,
    :station_id => station
  )

  flash[:notice] = 'Thanks for the report!'
  redirect '/reports'
end

# Only BART for now because that's where we're accepting reports
get '/api/bart/elevators.json' do
  content_type 'application/json'

  system = Models::System.first(:name => "BART")
  halt 404 if system.nil?

  Hash[system.stations.map do |station|
    [station.id,
     station.elevators.map do |elevator|
       { :text => elevator.name,
         :value => elevator.id }
     end]
  end].to_json
end

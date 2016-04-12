require 'models'

module Exports
  def self.outages_at_time(time, elevators)
    (Models::Outage.count(:started_at.lte => time,
                         :elevator => elevators,
                         :ended_at.gte => time) +
    Models::Outage.count(:started_at.lte => time,
                         :elevator => elevators,
                         :ended_at => nil))
  end

  def self.count_outages_per_fifteen_minutes
    # Limit to BART elevators for now
    elevators = self.bart_elevators

    start = DateTime.parse("October 17, 2015").to_time.utc.to_datetime
    finish = DateTime.now.to_time.utc.to_datetime
    fifteen_minutes_a_day = 1.to_f/(24*4)

    histogram = Hash.new(0)
    start.step(finish, fifteen_minutes_a_day).each do |time|
      puts "[#{start}, #{finish}, #{time}]"
      outages = self.outages_at_time(time, elevators)
      histogram[outages] += 1
    end

    return histogram
  end

  def self.bart_elevators
    Models::System.first(:name => "BART")
                  .stations
                  .flat_map(&:elevators)
                  .uniq
  end

  def self.raw_outages(elevators)
    Models::Outage.all(:elevator => elevators)
  end

  def self.outages_as_hashes(elevators)
    raw_outages(elevators).to_a.map do |outage|
      {
        'Elevator' => outage.elevator.name,
        'Start' => outage.started_at,
        'End' => outage.ended_at,
        'Length (hrs)' => outage.length.round(2)
      }
    end
  end

  def self.bart_raw_outage_dump
    data = outages_as_hashes(self.bart_elevators)
    csv = CSV.generate do |c|
      c << data.first.keys
      data.each {|row| c << row.values }
    end

    puts csv
  end

  def self.bart_elevator_dump
    elevators = self.bart_elevators
    csv = CSV.generate do |c|
      c << ["Elevator", "Number of outages", "Average outage length (hrs)", "Tota time out (hrs)"]

      elevators.each do |e|
        name = e.name
        outages = Models::Outage.all(:elevator => e)
        num_outages = outages.size
        total_time_out = outages.map(&:length)
                                .reduce(0, &:+)
                                .round(2)
        avg_outage_length = num_outages.zero? ? 0 : (total_time_out/num_outages).round(2)

        c << [e.name, num_outages, avg_outage_length, total_time_out]
      end
    end

    puts csv
  end
end

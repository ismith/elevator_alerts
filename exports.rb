require 'models'

module Exports
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

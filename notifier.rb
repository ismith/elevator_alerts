require 'models'

class Array
  # https://codereview.stackexchange.com/questions/5863/ruby-function-to-join-array-with-commas-and-a-conjunction
  def to_sentence
    default_connector = ', '
    two_word_connector = ' and '
    last_word_connector = ', and '

    case size
      when 0
        ""
      when 1
        self[0].to_s.dup
      when 2
        "#{self[0]}#{two_word_connector}#{self[1]}"
      else
        "#{self[0...-1].join(default_connector)}#{last_word_connector}#{self[-1]}"
    end
  end
end

class Notifier
  def self.send_elevator_notifications!(elevators)
    # We want to notify all users whose station-list includes an elevator
    # affected by the latest run
    users = elevators.flat_map(&:users).uniq

    users.each do |user|
      # Get all the out elevators that currently affect this user
      my_elevators = Models::Outage.all_open(:elevator => user.elevators.to_a) # Mumble-mumble
                                   .to_a # Mumble-mumble datamapper::collection
                                   .map(&:elevator)
                                   .map(&:name)

      message = elevator_notification_message(my_elevators)

      puts "Sending an email to user #{user.id}..."
      Email.mail(:to => user.email,
                 :subject => "BART Elevator Alerts",
                 :body => message)
    end

    users
  end

  private

  # @param [Array<String>] elevators
  #
  # @return [String]
  def self.elevator_notification_message(elevators)
    raise ArgumentError unless elevators.is_a?(Array) && elevators.all? { |e| e.class == String }
    case elevators.size
    when 0
      "All of the elevators you subscribe to are currently in service."
    when 1
      "1 of the elevators you subscribe to is out of service: #{elevators.first}."
    else
      "#{elevators.size} of the elevators you subscribe to are out of service: #{elevators.to_sentence}."
    end
  end
end

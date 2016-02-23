require 'models'
require 'my_twilio'

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
  def self.send_user_elevator_notification!(user, elevators)
    message = elevator_notification_message(elevators)

    if user.phone_number && user.phone_number_verified
      send_sms!(user, message)
    else
      send_email!(user, message)
    end
  end

  def self.send_email!(user, message)
      puts "Sending an email to user #{user.id}..."
      Email.mail(:to => user.email,
                 :subject => "Elevator Alerts",
                 :body => message)
  end

  def self.send_sms!(user, message)
    raise StandardError if user.phone_number.nil? || !user.phone_number_verified

    puts "Sending an SMS to user #{user.id} at phone number #{user.phone_number}"

    MyTwilio.send_sms(:to => user.phone_number,
                      :body => message)
  end

  def self.send_elevator_notifications!(elevators)
    # We want to notify all users whose station-list includes an elevator
    # affected by the latest run
    users = elevators.flat_map(&:users).uniq

    users.each do |user|
      # Get all the out elevators that currently affect this user
      my_elevators = Models::Outage.all_open(:elevator => user.elevators.to_a) # Mumble-mumble
                                   .to_a # Mumble-mumble datamapper::collection
                                   .map(&:elevator)

      send_user_elevator_notification!(user, my_elevators)
    end

    users
  end

  private

  # @param [Array<String>] elevators
  #
  # @return [String]
  def self.elevator_notification_message(elevators)
    elevators = elevators.map do |e|
      case e
      when String
        e
      when Models::Elevator
        e.name
      end
    end

    raise ArgumentError unless elevators.is_a?(Array) && elevators.all? { |e| e.class == String }
    case elevators.size
    when 0
      "All of your elevators are currently in service."
    when 1
      "1 of your elevators is out: #{elevators.first}."
    else
      "#{elevators.size} of your elevators are out: #{elevators.to_sentence}."
    end
  end
end

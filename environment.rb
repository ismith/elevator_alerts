module Environment
  REQUIRED_ENV_VARS = %w(
    DATABASE_URL
    ALLOWED_USERS
    SESSION_SECRET
    SESSION_DOMAIN
    PORT
  ).freeze

  OPTIONAL_ENV_VARS = %w(
    AUTHY_API_KEY
    GOOGLE_ANALYTICS_KEY
    GOOGLE_CLIENT_ID
    GOOGLE_CLIENT_SECRET
    ROLLBAR_ACCESS_TOKEN
    ROLLBAR_ENDPOINT
    SENDGRID_PASSWORD
    SENDGRID_USERNAME
    TWILIO_ACCOUNT_SID
    TWILIO_AUTH_TOKEN
    TWILIO_FROM_NUMBER
  ).freeze

  ENV_VARS_TO_CHANGE = {
    'PORT' => '4567',
    'SESSION_DOMAIN' => 'localhost'
    'SESSION_SECRET' => '52ea5dabe17d8263d5381a54920f55baa9b025fbdefd65fc605cd6d63bb08f60b6329fbbaf0d6c7718bfb350b6068743ddff1c2772cd7dc7a1177a8a7c2e2f91',
  }.freeze


  def self.check_env
    unless File.exists?('./.env')
      warn "You need a .env file - copy over .env.defaults and customize from there."
      exit 1
    end

    missing_required = REQUIRED_ENV_VARS.select { |key| ENV[key].blank? }

    unless missing_required.empty?
      warn "MISSING REQUIRED ENV VARIABLES:\n\t#{missing_required.join("\n\t")}"
    end

    missing_optional = OPTIONAL_ENV_VARS.select { |key| ENV[key].blank? }

    unless missing_optional.empty?
      warn "MISSING OPTIONAL ENV VARIABLES (not required for local development, probably necessary in prod):\n\t#{missing_optional.join("\n\t")}"
    end

    to_change = ENV_VARS_TO_CHANGE.select { |key, value| ENV[key] == value }

    unless to_change.empty?
      warn "DEFAULT VARIABlES (these are fine in local development, but should be changed in production):\n\t#{to_change.keys.join("\n\t")}"
    end

    unless REQUIRED_ENV_VARS.select { |key| ENV[key] }
                            .blank?
      exit 1
    end
  end

  def self.new_session_secret
    SecureRandom.hex(64)
  end
end

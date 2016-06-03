 [![Build Status](https://travis-ci.org/ismith/elevator_alerts.svg?branch=master)](https://travis-ci.org/ismith/elevator_alerts)
 
Local Setup
===========
The app consists of two parts, a webapp and a worker.  Both are defined in the
`Procfile`.  To start, install ruby 2.x and run `gem install bundler; bundle install`.

## Environment variables
You should now be able to run `forman run rake dev:check_environment`; we use
`.env` to set environment variables.  (In production on Heroku, we do similar
things with heroku config:set.)  Note that `.env` is in `.gitignore`; you can
use .env.defaults as a starter template.

## Database
You'll need postgres installed; that is left as an exercise for the reader.
Once you've done that, run:
```
createdb elevator_alerts
foreman run rake dev:load_seed_data['./data/seed.json']
```

(If you want to start over: `echo "DROP DATABASE elevator_alerts" | psql`, and
then run the above again.)

## Auth setup
For development mode, auth is handled locally by redirecting you to
`/auth/developer`, which will accept any email address and name it is given.
You should configure Google OAuth before deploying, instructions for which are
found below.

## Running the app
You can run either of `foreman run web` or `foreman run worker` or both; they
are independent, with `web` running the webapp and `worker` being used to query
public transit APIs and send notifications. You can also drop into a pry console
by running `foreman run rake console`.

Heroku
======

## Google Auth
This project uses `google-oauth2` (via [OmniAuth](https://github.com/intridea/omniauth)) for authentication.
You'll need to set up a [Google Developers Console
project](https://developers.google.com/identity/sign-in/web/devconsole-project)
and add `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` to your environment
variables.  You'll need to enable the `Google+` API, and edit the `Credentials`
tab with your `authorized redirect URIs` - for local development, this list should
include `http://localhost:4567/auth/login/callback`; you'll need to do this
again if and when you deploy elsewhere.

## Manual data maintenance
Periodically, you may wish to check for any newly-discovered Elevator records.
(That is, elevators reported by the API, but which have not been associated with
a station.)  To do this, run `Models::Elevator.stationless` from within the
console.

## Config
To get a local copy of heroku config:
```
heroku config -s >> .env
```

Heroku addons:
=============
heroku addons:create heroku-postgres:hobby-dev # 7k records
heroku addons:create sendgrid:starter # 400/day
heroku addons:create rollbar:free # 3000/mo, 30 days retention
heroku addons:create deployhooks:http [redacted] # you can get this from https://rollbar.com/elevatoralerts/elevatoralerts/deploys/

Note:
Not using heroku scheduler because it can only run hourly or every 10 minutes,
and I'm aiming for ~1/minute.

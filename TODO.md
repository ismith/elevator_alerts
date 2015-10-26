[x] First-or-create

[x] handler that takes a set of elevator-names and opens/closes outages appropriately
[x] test handler^Wworker
[x] runner for said handler

[x] seed station list - dumped as data/seed.sql
[x] Strip # and . from elevator names so SFO is handled properly?

[x] notifier code
[x] link notifier to outage code
[x] wire up heroku
  [x] wire up postgres
  [x] wire up sendgrid
  [x] wire up mailtrap?
[x] fix email sender
[x] Add admin notifier for errors
[x] Add admin notifier for new (stationless) elevators
[x] some metrics

[x] UI to configure notifications per-user
[x] encrypted sessions
[x] flash
[x] rack-csrf
[x] google analytics
[x] rollbar middleware in app


Maybe:
[ ] Use bundler groups for smarter requiring
[ ] shorten elevator names
[x] keen.io instead of silly Models::Metric
[ ] remove Models::Metric
[ ] better organization of initializers
[ ] graceful shutdown: https://devcenter.heroku.com/articles/dynos#the-dyno-manager
[ ] replace rest-client with faraday

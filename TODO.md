[x] First-or-create

[x] handler that takes a set of elevator-names and opens/closes outages appropriately
[x] test handler^Wworker
[x] runner for said handler

[x] seed station list - dumped as data/seed.sql
[x] Strip # and . from elevator names so SFO is handled properly?

[ ] notifier code
[x] link notifier to outage code
[ ] wire up heroku
  [x] wire up postgres
  [x] wire up sendgrid
  [x] wire up mailtrap?
[x] fix email sender
[x] Add admin notifier for errors
[x] Add admin notifier for new (stationless) elevators
[x] some metrics

[ ] UI to configure notifications per-user

[ ] shorten elevator names

Maybe:
[ ] dead man snitch
[ ] graphite instead of silly Models::Metric

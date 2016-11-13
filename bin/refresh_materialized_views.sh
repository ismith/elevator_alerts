#! /bin/bash

time echo "REFRESH MATERIALIZED VIEW bart_biz_hours;" | psql $DATABASE_URL

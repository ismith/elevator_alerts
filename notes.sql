-- generate days
CREATE OR REPLACE VIEW active_days AS
SELECT day FROM
(SELECT to_char(((SELECT min(outages.started_at) - '1 day'::interval FROM
outages)::date + (a ||' days')::interval), 'YYYY-MM-DD') as day from
generate_series(1,3650,1) a) as b
WHERE day::date <= now()::date + '1 day'::interval;

-- On sunday, 8-midnight
-- On saturday, 6-midnight
-- On weekdays, 4-midnight
CREATE MATERIALIZED VIEW bart_biz_hours AS
SELECT
  timestamptz (day || open_offset || ' US/Pacific')::timestamp as open,
  timestamptz (day || ' 24:00:00 US/Pacific')::timestamp as close,
  dow
FROM
(
SELECT
  day, dow,
  CASE WHEN dow = 0 THEN ' 08:00:00'
       WHEN dow = 6 THEN ' 06:00:00'
       ELSE ' 04:00:00'
  END as open_offset
FROM (SELECT day, date_part('dow'::text, day::date) as dow FROM active_days) as
dows) as offsets;

-- biz hour outages
CREATE VIEW bart_biz_hour_outages AS
  SELECT *, (close - open) AS duration FROM
    (SELECT outages.id, outages.elevator_id,
            GREATEST(bart_biz_hours.open, outages.started_at) AS open,
            LEAST(bart_biz_hours.close, outages.ended_at) AS close
     FROM outages
     JOIN elevators ON outages.elevator_id = elevators.id
     CROSS JOIN bart_biz_hours
     WHERE
       elevators.name NOT LIKE 'Muni%' AND
       (outages.started_at, COALESCE(outages.ended_at, NOW())) OVERLAPS (bart_biz_hours.open, bart_biz_hours.close)
    ) AS t ;

-- for a given elevator, sum the duration of its outages, and generate a
-- probabilty & percentage for each
 CREATE VIEW bart_biz_hour_elevator_outages AS
   SELECT elevator_name, elevator_id, station_id, sum,
   ROUND((EXTRACT(EPOCH from sum)/EXTRACT(EPOCH FROM total)*100)::decimal, 1) AS percentage,
   ROUND((EXTRACT(EPOCH from sum)/EXTRACT(EPOCH FROM total))::decimal, 3) AS probability
   FROM
    (SELECT elevators.name AS elevator_name, elevators.id AS elevator_id, station_id,
     SUM(duration) AS sum
     FROM elevators
     JOIN bart_biz_hour_outages ON elevator_id = elevators.id
     GROUP BY elevators.id
     ORDER BY elevators.station_id) AS u
   CROSS JOIN (SELECT SUM(close - open) AS total FROM bart_biz_hours) AS t;

-- singleton stations:
CREATE VIEW singleton_station_outages AS
  SELECT station_id, stations.name,
         probability,
         percentage,
         'singleton'::text AS station_type
  FROM bart_biz_hour_elevator_outages
  JOIN stations ON station_id = stations.id
  WHERE station_id IN (7, 19, 44, 41, 6, 29, 28, 15, 31, 23, 8, 36, 37, 12, 21);

-- series stations:
CREATE VIEW series_street_outages AS
  SELECT station_id, outages.* from outages
  JOIN elevators ON outages.elevator_id = elevators.id
  WHERE station_id IN (2, 3, 4, 9, 14, 18, 24, 27, 32, 34)
  AND   name LIKE '%Street%';

CREATE VIEW series_platform_outages AS
  SELECT station_id, outages.* from outages
  JOIN elevators ON outages.elevator_id = elevators.id
  WHERE station_id IN (2, 3, 4, 9, 14, 18, 24, 27, 32, 34)
  AND   name LIKE '%Street%';

CREATE VIEW series_overlapping_outages AS
  SELECT series_street_outages.station_id,
         GREATEST(series_street_outages.started_at,
                  series_platform_outages.started_at) AS open,
         LEAST(series_street_outages.ended_at,
               series_platform_outages.ended_at) AS close
  FROM series_street_outages
  JOIN series_platform_outages
  ON series_street_outages.station_id = series_platform_outages.station_id
  WHERE (series_street_outages.started_at,
         COALESCE(series_street_outages.ended_at, NOW()))
    OVERLAPS (series_platform_outages.started_at,
              COALESCE(series_platform_outages.ended_at, NOW()));

CREATE VIEW series_overlapping_biz_hour_outages AS
  SELECT station_id, SUM(duration)
  FROM
    (SELECT *, (close - open) AS duration
     FROM
       (SELECT station_id,
               GREATEST(series_overlapping_outages.open, bart_biz_hours.open) AS open,
               LEAST(series_overlapping_outages.close, bart_biz_hours.close) AS close
        FROM series_overlapping_outages
        CROSS JOIN bart_biz_hours
        WHERE (series_overlapping_outages.open,
               COALESCE(series_overlapping_outages.close, NOW()))
          OVERLAPS (bart_biz_hours.open, bart_biz_hours.close)) AS t) AS u
  GROUP BY station_id;

CREATE VIEW series_station_outages AS
  SELECT station_id, name,
         ROUND((EXTRACT(EPOCH from sum)/EXTRACT(EPOCH FROM total))::decimal, 3) AS probability,
         ROUND((EXTRACT(EPOCH from sum)/EXTRACT(EPOCH FROM total)*100)::decimal, 1) AS percentage,
         'series'::text AS station_type
  FROM
    (SELECT t.station_id, (sum - overlap_sum) AS sum
     FROM (SELECT station_id, SUM(sum)
           FROM bart_biz_hour_elevator_outages
           WHERE station_id IN (2, 3, 4, 9, 14, 18, 24, 27, 32, 34)
           GROUP BY station_id) AS t
     JOIN (SELECT station_id, sum AS overlap_sum
           FROM series_overlapping_biz_hour_outages) AS u
     ON t.station_id = u.station_id) AS v
  JOIN stations ON stations.id = station_id
  CROSS JOIN (SELECT SUM(close - open) AS total FROM bart_biz_hours) AS w;

-- compare old and new (used to do statistical analysis of series stations, but
-- later improved our approach)
-- SELECT series_station_outages_old.station_id,
--        stations.name,
--        series_station_outages_old.percentage,
--        series_station_outages.percentage,
--        (series_station_outages_old.percentage - series_station_outages.percentage)
-- FROM series_station_outages
-- JOIN series_station_outages2
-- ON series_station_outages_old.station_id = series_station_outages.station_id
-- JOIN stations ON stations.id = series_station_outages_old.station_id;

--CREATE VIEW series_station_outages_old AS
--  SELECT station_id, name,
--         (1 - (1 - p1)*(1 - p2)) AS probability,
--         (1 - (1 - p1)*(1 - p2))*100 AS percentage,
--         'series'::text AS station_type
--  FROM
--    (SELECT station_id, name,
--            MIN(probability) AS p1,
--            MAX(probability) AS p2
--     FROM bart_biz_hour_elevator_outages
--     JOIN stations ON station_id = stations.id
--     WHERE station_id IN (2, 3, 4, 9, 14, 18, 24, 27, 32, 34)
--     GROUP BY station_id, name) AS probs;

-- parallel stations
CREATE VIEW parallel_station_outages AS
  SELECT station_id, name,
         AVG(probability) AS probability,
         AVG(percentage) AS percentage,
         'parallel'::text AS station_type
  FROM bart_biz_hour_elevator_outages
  JOIN stations ON station_id = stations.id
  WHERE station_id IN (11, 16, 17, 20, 22, 25, 33, 39, 40, 42, 43, 45)
  GROUP BY station_id, name;

-- outageless stations
CREATE VIEW outageless_stations AS
  SELECT id AS station_id, name,
         0 AS probability, 0 AS percentage,
         'outageless'::text AS station_type
  FROM stations
  WHERE id NOT IN (SELECT DISTINCT station_id
                   FROM bart_biz_hour_elevator_outages)
  AND name NOT LIKE 'Muni%';

-- special cases
CREATE VIEW ashby_outages AS
  SELECT station_id, name, probability, percentage,
         'special_case'::text AS station_type
  FROM bart_biz_hour_elevator_outages
  JOIN stations ON station_id = stations.id
  WHERE elevator_id = 43;

-- 12th St
-- average the two street elevators, then treat as a series station
CREATE VIEW twelfth_st_outages AS
  SELECT station_id, name,
         (1 - (1 - p1)*(1 - p2)) AS probability,
         (1 - (1 - p1)*(1 - p2))*100 AS percentage,
         'special_case'::text AS station_type
  FROM (SELECT station_id, probability AS p1, p2
        FROM bart_biz_hour_elevator_outages
        CROSS JOIN
          (SELECT AVG(probability) AS p2
           FROM bart_biz_hour_elevator_outages
           WHERE elevator_id IN (1, 4)
           GROUP BY station_id) AS street
        WHERE elevator_id = 21) as probs
  JOIN stations ON station_id = stations.id;


-- UNION all the station-outage tables together
CREATE VIEW station_outages AS
  SELECT station_id, name,
         station_type,
         ROUND(probability, 3) AS probability,
         ROUND(percentage, 1) AS percentage
  FROM
    (SELECT * FROM singleton_station_outages
     UNION SELECT * FROM series_station_outages
     UNION SELECT * FROM parallel_station_outages
     UNION SELECT * FROM outageless_stations
     UNION SELECT * FROM ashby_outages
     UNION SELECT * FROM twelfth_st_outages
     ORDER BY percentage DESC ) AS u;

-- Add some analytics for funsies
CREATE VIEW analytics_station_outages AS
SELECT NULLIF(GREATEST(row_number() OVER () - 2, 0), 0) AS rank,
       station_id, name, station_type, probability, percentage
FROM
  (SELECT sort_order, station_id, name, station_type, probability, percentage
  FROM (SELECT NULL AS station_id, 'AVERAGE'::text AS name, NULL AS station_type,
               ROUND(AVG(probability), 3) AS probability,
               ROUND(AVG(percentage), 1) AS percentage,
               0 AS sort_order
        FROM station_outages
        UNION SELECT *, 100 AS sort_order FROM station_outages) AS t
  UNION SELECT 1 AS sort_order, NULL AS station_id, 'PER TRIP'::text AS name, NULL AS station_type,
               ROUND((1 - POW((1 - AVG(probability)), 2)), 3) AS probability,
               ROUND((1 - POW((1 - AVG(probability)), 2))*100, 1) AS percentage
        FROM station_outages
  ORDER BY sort_order ASC, probability DESC) AS u;

-- station-pair analytics
CREATE VIEW analytics_station_pairs AS
SELECT row_number() OVER (), *
FROM (SELECT station_outages.name as name1, u.name as name2,
               ROUND(1 - (1 - station_outages.probability)*(1-u.probability),3) AS probability,
               ROUND((1 - (1 - station_outages.probability)*(1-u.probability))*100,1) AS percentage
      FROM station_outages
      CROSS JOIN (SELECT * FROM station_outages) AS u
      JOIN stations ON stations.id = station_outages.station_id
      WHERE station_outages.station_id < u.station_id
      ORDER BY percentage DESC) as t;

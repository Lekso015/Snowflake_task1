CREATE OR REPLACE PROCEDURE airline_dwh.raw.load_stage1()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
  rows_loaded NUMBER;
BEGIN
  COPY INTO airline_dwh.raw.airline_raw
  FROM @airline_dwh.raw.airline_stage
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"')
  ON_ERROR = 'CONTINUE';

  SELECT SUM("rows_loaded") INTO :rows_loaded
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

  INSERT INTO airline_dwh.gold.audit_log (procedure_name, target_table, rows_inserted, rows_updated)
  VALUES ('load_stage1', 'raw.airline_raw', :rows_loaded, 0);

  COMMIT;
  RETURN 'Stage 1 load complete: ' || :rows_loaded || ' rows loaded';
END;
$$;

--Procedure that reads the stream and merges it into silver 
CREATE OR REPLACE PROCEDURE airline_dwh.silver.load_silver()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  MERGE INTO airline_dwh.silver.airline_cleaned AS tgt
  USING (
    SELECT
        INDEX AS idx, PASSENGER AS passenger_id, FIRST_NAME AS first_name, LAST_NAME AS last_name,
        GENDER AS gender, AGE AS age, NATIONALITY AS nationality, AIRPORT_NAME AS airport_name,
        AIRPORT_COUNTRY_CODE AS airport_country_code, COUNTRY_NAME AS country_name,
        AIRPORT_CONTINENT AS airport_continent, CONTINENTS AS continent, DEPARTURE_DATE AS departure_date,
        ARRIVAL_AIRPORT AS arrival_airport, PILOT_NAME AS pilot_name, FLIGHT_STATUS AS flight_status,
        TICKET_TYPE AS ticket_type, PASSENGER_STATUS AS passenger_status
    FROM airline_dwh.raw.airline_raw_stream
    WHERE METADATA$ACTION = 'INSERT'
  ) AS src
  ON tgt.idx = src.idx
  WHEN MATCHED THEN UPDATE SET
    tgt.passenger_id = src.passenger_id, tgt.first_name = src.first_name, tgt.last_name = src.last_name,
    tgt.gender = src.gender, tgt.age = src.age, tgt.nationality = src.nationality,
    tgt.airport_name = src.airport_name, tgt.airport_country_code = src.airport_country_code,
    tgt.country_name = src.country_name, tgt.airport_continent = src.airport_continent,
    tgt.continent = src.continent, tgt.departure_date = src.departure_date,
    tgt.arrival_airport = src.arrival_airport, tgt.pilot_name = src.pilot_name,
    tgt.flight_status = src.flight_status, tgt.ticket_type = src.ticket_type,
    tgt.passenger_status = src.passenger_status
  WHEN NOT MATCHED THEN INSERT (
    idx, passenger_id, first_name, last_name, gender, age, nationality, airport_name,
    airport_country_code, country_name, airport_continent, continent, departure_date,
    arrival_airport, pilot_name, flight_status, ticket_type, passenger_status
  ) VALUES (
    src.idx, src.passenger_id, src.first_name, src.last_name, src.gender, src.age, src.nationality,
    src.airport_name, src.airport_country_code, src.country_name, src.airport_continent, src.continent,
    src.departure_date, src.arrival_airport, src.pilot_name, src.flight_status, src.ticket_type, src.passenger_status
  );

  INSERT INTO airline_dwh.gold.audit_log (procedure_name, target_table, rows_inserted, rows_updated)
  SELECT 'load_silver', 'silver.airline_cleaned', "number of rows inserted", "number of rows updated"
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

  COMMIT;
  RETURN 'Silver load complete';
END;
$$;
--So silver layer is set.


--Gold Tables Update from silver 
CREATE OR REPLACE PROCEDURE airline_dwh.gold.load_gold()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  CREATE OR REPLACE TEMPORARY TABLE silver_delta AS
  SELECT * FROM airline_dwh.silver.airline_cleaned_stream WHERE METADATA$ACTION = 'INSERT';

  MERGE INTO airline_dwh.gold.dim_passenger AS tgt
  USING (SELECT DISTINCT passenger_id, first_name, last_name, gender, age, nationality FROM silver_delta) AS src
  ON tgt.passenger_id = src.passenger_id
  WHEN MATCHED THEN UPDATE SET
    tgt.first_name = src.first_name, tgt.last_name = src.last_name,
    tgt.gender = src.gender, tgt.age = src.age, tgt.nationality = src.nationality
  WHEN NOT MATCHED THEN INSERT (passenger_id, first_name, last_name, gender, age, nationality)
  VALUES (src.passenger_id, src.first_name, src.last_name, src.gender, src.age, src.nationality);

  INSERT INTO airline_dwh.gold.audit_log (procedure_name, target_table, rows_inserted, rows_updated)
  SELECT 'load_gold', 'gold.dim_passenger', "number of rows inserted", "number of rows updated"
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

  MERGE INTO airline_dwh.gold.dim_airport AS tgt
  USING (SELECT DISTINCT airport_name, airport_country_code, country_name, airport_continent AS continent FROM silver_delta) AS src
  ON tgt.airport_name = src.airport_name AND tgt.country_code = src.airport_country_code
  WHEN MATCHED THEN UPDATE SET
    tgt.country_name = src.country_name, tgt.continent = src.continent
  WHEN NOT MATCHED THEN INSERT (airport_name, country_code, country_name, continent)
  VALUES (src.airport_name, src.airport_country_code, src.country_name, src.continent);

  INSERT INTO airline_dwh.gold.audit_log (procedure_name, target_table, rows_inserted, rows_updated)
  SELECT 'load_gold', 'gold.dim_airport', "number of rows inserted", "number of rows updated"
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

  MERGE INTO airline_dwh.gold.dim_pilot AS tgt
  USING (SELECT DISTINCT pilot_name FROM silver_delta) AS src
  ON tgt.pilot_name = src.pilot_name
  WHEN NOT MATCHED THEN INSERT (pilot_name) VALUES (src.pilot_name);

  INSERT INTO airline_dwh.gold.audit_log (procedure_name, target_table, rows_inserted, rows_updated)
  SELECT 'load_gold', 'gold.dim_pilot', "number of rows inserted", 0
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

  MERGE INTO airline_dwh.gold.dim_date AS tgt
  USING (
    SELECT DISTINCT
        TO_NUMBER(TO_CHAR(departure_date, 'YYYYMMDD')) AS date_key, departure_date AS full_date,
        YEAR(departure_date) AS year, MONTH(departure_date) AS month, DAY(departure_date) AS day,
        DAYNAME(departure_date) AS weekday
    FROM silver_delta WHERE departure_date IS NOT NULL
  ) AS src
  ON tgt.date_key = src.date_key
  WHEN NOT MATCHED THEN INSERT (date_key, full_date, year, month, day, weekday)
  VALUES (src.date_key, src.full_date, src.year, src.month, src.day, src.weekday);

  INSERT INTO airline_dwh.gold.audit_log (procedure_name, target_table, rows_inserted, rows_updated)
  SELECT 'load_gold', 'gold.dim_date', "number of rows inserted", 0
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

  MERGE INTO airline_dwh.gold.fact_flight_bookings AS tgt
  USING (
    SELECT s.idx AS booking_source_id, p.passenger_key, a.airport_key, pi.pilot_key, d.date_key,
        s.arrival_airport, s.flight_status, s.ticket_type, s.passenger_status
    FROM silver_delta s
    JOIN airline_dwh.gold.dim_passenger p ON p.passenger_id = s.passenger_id
    JOIN airline_dwh.gold.dim_airport a ON a.airport_name = s.airport_name AND a.country_code = s.airport_country_code
    JOIN airline_dwh.gold.dim_pilot pi ON pi.pilot_name = s.pilot_name
    JOIN airline_dwh.gold.dim_date d ON d.full_date = s.departure_date
  ) AS src
  ON tgt.booking_key = src.booking_source_id
  WHEN NOT MATCHED THEN INSERT (passenger_key, airport_key, pilot_key, date_key, arrival_airport, flight_status, ticket_type, passenger_status)
  VALUES (src.passenger_key, src.airport_key, src.pilot_key, src.date_key, src.arrival_airport, src.flight_status, src.ticket_type, src.passenger_status);

  INSERT INTO airline_dwh.gold.audit_log (procedure_name, target_table, rows_inserted, rows_updated)
  SELECT 'load_gold', 'gold.fact_flight_bookings', "number of rows inserted", 0
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

  COMMIT;
  RETURN 'Gold load complete';
END;
$$;



TRUNCATE TABLE airline_dwh.gold.fact_flight_bookings;
TRUNCATE TABLE airline_dwh.gold.dim_passenger;
TRUNCATE TABLE airline_dwh.gold.dim_airport;
TRUNCATE TABLE airline_dwh.gold.dim_pilot;
TRUNCATE TABLE airline_dwh.gold.dim_date;
TRUNCATE TABLE airline_dwh.silver.airline_cleaned;
TRUNCATE TABLE airline_dwh.raw.airline_raw;


CALL airline_dwh.raw.load_stage1();
SELECT COUNT(*) FROM airline_dwh.raw.airline_raw;                -- expect: full source row count

CALL airline_dwh.silver.load_silver();
SELECT COUNT(*) FROM airline_dwh.silver.airline_cleaned;         

CALL airline_dwh.gold.load_gold();
SELECT COUNT(*) FROM airline_dwh.gold.dim_passenger;             
SELECT COUNT(*) FROM airline_dwh.gold.dim_airport;                -- expect: distinct airport count
SELECT COUNT(*) FROM airline_dwh.gold.dim_pilot;                   
SELECT COUNT(*) FROM airline_dwh.gold.dim_date;                     
SELECT COUNT(*) FROM airline_dwh.gold.fact_flight_bookings;    



--test with change 

UPDATE airline_dwh.raw.airline_raw 
SET first_name = 'TESTNAME' 
WHERE index = 0;
SELECT index, first_name FROM airline_dwh.raw.airline_raw LIMIT 5;
CALL airline_dwh.silver.load_silver();
SELECT SYSTEM$STREAM_HAS_DATA('airline_dwh.silver.airline_cleaned_stream');
CALL airline_dwh.gold.load_gold();
SELECT * FROM airline_dwh.gold.audit_log ORDER BY run_timestamp DESC LIMIT 6;
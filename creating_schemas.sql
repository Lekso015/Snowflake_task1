CREATE DATABASE airline_dwh;
CREATE SCHEMA airline_dwh.raw;
CREATE SCHEMA airline_dwh.silver;
CREATE SCHEMA airline_dwh.gold;

CALL airline_dwh.raw.load_stage1();
SELECT COUNT(*) FROM airline_dwh.raw.airline_raw;

SHOW WAREHOUSES;

describe table airline_dwh.raw.airline_raw;

-- Creating Second Stage table(silver layer)
CREATE TABLE airline_dwh.silver.airline_cleaned(
    idx                     NUMBER,
    passenger_id            VARCHAR,
    first_name              VARCHAR,
    last_name               VARCHAR,
    gender                  VARCHAR,
    age                     NUMBER,
    nationality             VARCHAR,
    airport_name            VARCHAR,
    airport_country_code    VARCHAR,
    country_name            VARCHAR,
    airport_continent       VARCHAR,
    continent               VARCHAR,
    departure_date          DATE,
    arrival_airport         VARCHAR,
    pilot_name              VARCHAR,
    flight_status           VARCHAR,
    ticket_type             VARCHAR,
    passenger_status        VARCHAR
);

describe table airline_dwh.silver.airline_cleaned;



--3 stage tables 1 fact 4 dimension(Star Schema)

CREATE TABLE airline_dwh.gold.dim_passenger (
    passenger_key   NUMBER AUTOINCREMENT PRIMARY KEY,
    passenger_id    VARCHAR,
    first_name      VARCHAR,
    last_name       VARCHAR,
    gender          VARCHAR,
    age             NUMBER,
    nationality     VARCHAR
);

CREATE TABLE airline_dwh.gold.dim_airport (
    airport_key     NUMBER AUTOINCREMENT PRIMARY KEY,
    airport_name    VARCHAR,
    country_code    VARCHAR,
    country_name    VARCHAR,
    continent       VARCHAR
);

CREATE TABLE airline_dwh.gold.dim_pilot (
    pilot_key   NUMBER AUTOINCREMENT PRIMARY KEY,
    pilot_name  VARCHAR
);

CREATE TABLE airline_dwh.gold.dim_date (
    date_key    NUMBER PRIMARY KEY,   
    full_date   DATE,
    year        NUMBER,
    month       NUMBER,
    day         NUMBER,
    weekday     VARCHAR
);

CREATE TABLE airline_dwh.gold.fact_flight_bookings (
    booking_key         NUMBER AUTOINCREMENT PRIMARY KEY,
    passenger_key        NUMBER REFERENCES dim_passenger(passenger_key),
    airport_key          NUMBER REFERENCES dim_airport(airport_key),
    pilot_key             NUMBER REFERENCES dim_pilot(pilot_key),
    date_key               NUMBER REFERENCES dim_date(date_key),
    arrival_airport      VARCHAR,    
    flight_status        VARCHAR,
    ticket_type           VARCHAR,
    passenger_status    VARCHAR
);

show tables  IN SCHEMA airline_dwh.gold;


--So we created 7 tables 1 raw 1 silver 5 gold, in instructions we were given task to create 5-10 tables.


CREATE TABLE airline_dwh.gold.audit_log (
    audit_id        NUMBER AUTOINCREMENT PRIMARY KEY,
    procedure_name  VARCHAR,
    target_table    VARCHAR,
    rows_inserted   NUMBER,
    rows_updated    NUMBER,
    run_timestamp   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
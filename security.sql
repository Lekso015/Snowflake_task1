CREATE OR REPLACE ROW ACCESS POLICY airline_dwh.gold.nationality_policy
AS (nationality VARCHAR) RETURNS BOOLEAN ->
  CURRENT_ROLE() = 'ACCOUNTADMIN'  
  OR nationality = 'United States';

--secure view
CREATE OR REPLACE SECURE VIEW airline_dwh.gold.secure_fact_flight_bookings AS
SELECT 
    f.booking_key, f.passenger_key, f.airport_key, f.pilot_key, f.date_key,
    f.arrival_airport, f.flight_status, f.ticket_type, f.passenger_status,
    p.nationality
FROM airline_dwh.gold.fact_flight_bookings f
JOIN airline_dwh.gold.dim_passenger p ON f.passenger_key = p.passenger_key;



ALTER VIEW airline_dwh.gold.secure_fact_flight_bookings
ADD ROW ACCESS POLICY airline_dwh.gold.nationality_policy ON (nationality);



--Test as admin
SELECT COUNT(*) FROM airline_dwh.gold.secure_fact_flight_bookings;
SELECT COUNT(*) FROM airline_dwh.gold.fact_flight_bookings;  


--Better test case
CREATE ROLE test_analyst;
GRANT USAGE ON DATABASE airline_dwh TO ROLE test_analyst;
GRANT USAGE ON SCHEMA airline_dwh.gold TO ROLE test_analyst;
GRANT SELECT ON airline_dwh.gold.secure_fact_flight_bookings TO ROLE test_analyst;
GRANT ROLE test_analyst TO USER lekso15;

USE ROLE test_analyst;
SELECT COUNT(*) FROM airline_dwh.gold.secure_fact_flight_bookings;  -- should be LESS than 98260

USE ROLE ACCOUNTADMIN;

-- It works shows only 2100 rows.
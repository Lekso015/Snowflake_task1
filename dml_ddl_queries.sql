SELECT CURRENT_TIMESTAMP();


--query data as it existed in the past
SELECT index, first_name 
FROM airline_dwh.raw.airline_raw 
AT(OFFSET => -60*10)  
WHERE index = 0;


--restore/recover old data using Time Travel
UPDATE airline_dwh.raw.airline_raw AS tgt
SET first_name = (
    SELECT first_name 
    FROM airline_dwh.raw.airline_raw AT(OFFSET => -60*10)
    WHERE index = tgt.index
)
WHERE index = 0;

--testing if recovered
select index,first_name
from airline_dwh.raw.airline_raw
where index = 0;

--clone a table as it existed before a change
CREATE TABLE airline_dwh.raw.airline_raw_backup
CLONE airline_dwh.raw.airline_raw
AT(OFFSET => -60*10);

-- Undrop table
DROP TABLE airline_dwh.raw.airline_raw_backup;
UNDROP TABLE airline_dwh.raw.airline_raw_backup;

SELECT * FROM airline_dwh.gold.audit_log WHERE target_table = 'silver.airline_cleaned' ORDER BY run_timestamp DESC LIMIT 1;
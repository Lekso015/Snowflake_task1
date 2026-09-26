CREATE STAGE airline_dwh.raw.airline_stage
  FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"');

--creating stream for raw table

CREATE OR REPLACE STREAM airline_dwh.raw.airline_raw_stream
  ON TABLE airline_dwh.raw.airline_raw;

--Stream for silver table
CREATE OR REPLACE STREAM airline_dwh.silver.airline_cleaned_stream
    ON TABLE airline_dwh.silver.airline_cleaned;
    
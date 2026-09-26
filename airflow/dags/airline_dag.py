from airflow import DAG
from airflow.providers.snowflake.operators.snowflake import SQLExecuteQueryOperator
from datetime import datetime

with DAG(
    dag_id="airline_main_pipeline",
    start_date=datetime(2026, 1, 1),
    schedule=None,  # trigger manually; add a cron schedule later if needed
    catchup=False,
    tags=["snowflake", "airline"],
) as dag:

    load_stage1 = SQLExecuteQueryOperator(
        task_id="load_stage1",
        conn_id="snowflake_conn",
        sql="CALL airline_dwh.raw.load_stage1();",
    )

    load_silver = SQLExecuteQueryOperator(
        task_id="load_silver",
        conn_id="snowflake_conn",
        sql="CALL airline_dwh.silver.load_silver();",
    )

    load_gold = SQLExecuteQueryOperator(
        task_id="load_gold",
        conn_id="snowflake_conn",
        sql="CALL airline_dwh.gold.load_gold();",
    )

    load_stage1 >> load_silver >> load_gold
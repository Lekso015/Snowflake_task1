from airflow import DAG
from airflow.providers.snowflake.operators.snowflake import SQLExecuteQueryOperator
from datetime import datetime

with DAG(
    dag_id="test_snowflake_connection",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
) as dag:
    test_task = SQLExecuteQueryOperator(
        task_id="test_query",
        conn_id="snowflake_conn",  # whatever you named it
        sql="SELECT CURRENT_VERSION();",
    )
# Databricks notebook source
# MAGIC %md
# MAGIC # 00 Setup
# MAGIC Creates catalog `weather_iot`, schemas `silver` and `gold`, and the Delta tables (external, files in the lake).
# MAGIC Safe to run on every job run.

# COMMAND ----------
dbutils.widgets.text("storage_account", "stweatheriotgpwjq")
sa = dbutils.widgets.get("storage_account")

CATALOG = "weather_iot"
SILVER_PATH = f"abfss://silver@{sa}.dfs.core.windows.net"
GOLD_PATH = f"abfss://gold@{sa}.dfs.core.windows.net"
MANAGED_PATH = f"abfss://uc-managed@{sa}.dfs.core.windows.net/weather_iot"

# Deletion vectors off: Synapse serverless (Layer 5) cannot read them
PROPS = "TBLPROPERTIES ('delta.enableDeletionVectors' = 'false')"

# COMMAND ----------
spark.sql(f"CREATE CATALOG IF NOT EXISTS {CATALOG} MANAGED LOCATION '{MANAGED_PATH}'")
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CATALOG}.silver")
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CATALOG}.gold")

# COMMAND ----------
spark.sql(f"""
CREATE TABLE IF NOT EXISTS {CATALOG}.silver.weather_readings (
  schema_version STRING, `source` STRING, sensor_id STRING,
  city_id STRING, city STRING, country STRING, lat DOUBLE, lon DOUBLE,
  event_ts TIMESTAMP, aq_event_ts TIMESTAMP, ingest_ts TIMESTAMP, event_date DATE,
  temp_c DOUBLE, feels_like_c DOUBLE, humidity_pct INT, pressure_hpa INT,
  wind_speed_ms DOUBLE, wind_deg INT, clouds_pct INT, visibility_m INT, weather_main STRING,
  aqi INT, co DOUBLE, `no` DOUBLE, no2 DOUBLE, o3 DOUBLE, so2 DOUBLE,
  pm2_5 DOUBLE, pm10 DOUBLE, nh3 DOUBLE,
  _bronze_file STRING, _silver_loaded_at TIMESTAMP
) USING DELTA LOCATION '{SILVER_PATH}/weather_readings' {PROPS}
""")

spark.sql(f"""
CREATE TABLE IF NOT EXISTS {CATALOG}.silver.weather_rejects (
  reject_reason STRING, city_id STRING, event_ts TIMESTAMP, ingest_ts TIMESTAMP,
  temp_c DOUBLE, humidity_pct INT, pressure_hpa INT, aqi INT, pm2_5 DOUBLE,
  _bronze_file STRING, _rejected_at TIMESTAMP
) USING DELTA LOCATION '{SILVER_PATH}/weather_rejects' {PROPS}
""")

spark.sql(f"""
CREATE TABLE IF NOT EXISTS {CATALOG}.gold.weather_daily (
  city_id STRING, city STRING, country STRING, event_date DATE, readings INT,
  avg_temp_c DOUBLE, min_temp_c DOUBLE, max_temp_c DOUBLE,
  avg_humidity_pct DOUBLE, avg_pressure_hpa DOUBLE,
  avg_wind_speed_ms DOUBLE, max_wind_speed_ms DOUBLE,
  avg_aqi DOUBLE, max_aqi INT, avg_pm2_5 DOUBLE, max_pm2_5 DOUBLE, avg_pm10 DOUBLE,
  readings_aqi_1 INT, readings_aqi_2 INT, readings_aqi_3 INT, readings_aqi_4 INT, readings_aqi_5 INT,
  is_complete_day BOOLEAN, _gold_loaded_at TIMESTAMP
) USING DELTA LOCATION '{GOLD_PATH}/weather_daily' {PROPS}
""")

spark.sql(f"""
CREATE TABLE IF NOT EXISTS {CATALOG}.gold.weather_rolling_7d (
  city_id STRING, event_date DATE, days_in_window INT, readings_in_window INT,
  roll7_avg_temp_c DOUBLE, roll7_avg_humidity_pct DOUBLE,
  roll7_avg_pm2_5 DOUBLE, roll7_avg_aqi DOUBLE, _gold_loaded_at TIMESTAMP
) USING DELTA LOCATION '{GOLD_PATH}/weather_rolling_7d' {PROPS}
""")

# COMMAND ----------
display(spark.sql(f"SHOW TABLES IN {CATALOG}.silver"))
display(spark.sql(f"SHOW TABLES IN {CATALOG}.gold"))
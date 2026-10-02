# Databricks notebook source
# MAGIC %md
# MAGIC # 01 Bronze to Silver
# MAGIC Reads the last N days of raw Parquet, casts types, validates, removes duplicates on `(city_id, event_ts)`,
# MAGIC then MERGEs into the silver Delta table. Bad rows go to `weather_rejects` with a reason.

# COMMAND ----------
from datetime import datetime, timedelta
from delta.tables import DeltaTable
from pyspark.sql import Window
from pyspark.sql import functions as F

dbutils.widgets.text("storage_account", "stweatheriotgpwjq")
dbutils.widgets.text("lookback_days", "2")
sa = dbutils.widgets.get("storage_account")
lookback = int(dbutils.widgets.get("lookback_days"))

BRONZE = f"abfss://bronze@{sa}.dfs.core.windows.net/raw"
SILVER = "weather_iot.silver.weather_readings"
REJECTS = "weather_iot.silver.weather_rejects"
start_date = (datetime.utcnow() - timedelta(days=lookback)).strftime("%Y-%m-%d")
print("Reading bronze from", start_date)

# New bronze columns are accepted automatically (schema evolution)
spark.conf.set("spark.databricks.delta.schema.autoMerge.enabled", "true")

# COMMAND ----------
# Read (partition folders date=.. and hour=.. become columns, so the filter skips old folders)
raw = (spark.read.option("mergeSchema", "true").parquet(BRONZE)
       .filter(F.col("date") >= F.lit(start_date))
       .select("*", F.col("_metadata.file_path").alias("_bronze_file"))
       .drop("date", "hour"))

# Cast to the types silver expects
typed = raw
for c in ["lat", "lon", "temp_c", "feels_like_c", "wind_speed_ms", "co", "no", "no2", "o3", "so2", "pm2_5", "pm10", "nh3"]:
    typed = typed.withColumn(c, F.col(c).cast("double"))
for c in ["humidity_pct", "pressure_hpa", "wind_deg", "clouds_pct", "visibility_m", "aqi"]:
    typed = typed.withColumn(c, F.col(c).cast("int"))
for c in ["event_ts", "aq_event_ts", "ingest_ts"]:
    typed = typed.withColumn(c, F.col(c).cast("timestamp"))
typed = typed.withColumn("event_date", F.to_date("event_ts"))

# COMMAND ----------
# Validation: the first failing rule becomes the reject reason
def bad(valid):  # True when the value is missing or outside the allowed range
    return F.coalesce(~valid, F.lit(True))

checked = typed.withColumn("reject_reason",
    F.when(F.col("city_id").isNull() | (F.col("city_id") == ""), "missing_city_id")
     .when(F.col("event_ts").isNull(), "missing_event_ts")
     .when(bad(F.col("temp_c").between(-90, 60)), "temp_out_of_range")
     .when(bad(F.col("humidity_pct").between(0, 100)), "humidity_out_of_range")
     .when(bad(F.col("pressure_hpa").between(850, 1090)), "pressure_out_of_range")
     .when(bad(F.col("aqi").between(1, 5)), "aqi_out_of_range")
     .when(F.coalesce(F.col("pm2_5") < 0, F.lit(False)), "negative_pm2_5"))

good = checked.filter(F.col("reject_reason").isNull()).drop("reject_reason")
rejected = checked.filter(F.col("reject_reason").isNotNull())

# COMMAND ----------
# Deduplicate: keep the earliest-ingested row for each (city_id, event_ts)
w = Window.partitionBy("city_id", "event_ts").orderBy(F.col("ingest_ts").asc(), F.col("_bronze_file").asc())
dedup = (good.withColumn("_rn", F.row_number().over(w)).filter("_rn = 1").drop("_rn")
         .withColumn("_silver_loaded_at", F.current_timestamp()))

# COMMAND ----------
# MERGE: re-running never creates duplicates
(DeltaTable.forName(spark, SILVER).alias("t")
 .merge(dedup.alias("s"), "t.city_id = s.city_id AND t.event_ts = s.event_ts")
 .whenNotMatchedInsertAll()
 .execute())

rej = (rejected.select("reject_reason", "city_id", "event_ts", "ingest_ts", "temp_c",
                       "humidity_pct", "pressure_hpa", "aqi", "pm2_5", "_bronze_file")
       .withColumn("_rejected_at", F.current_timestamp())
       .dropDuplicates(["reject_reason", "city_id", "event_ts"]))
(DeltaTable.forName(spark, REJECTS).alias("t")
 .merge(rej.alias("s"), "t.reject_reason = s.reject_reason AND t.city_id <=> s.city_id AND t.event_ts <=> s.event_ts")
 .whenNotMatchedInsertAll()
 .execute())

# COMMAND ----------
print("bronze rows read       :", raw.count())
print("rejected (bad values)  :", rejected.count())
print("after dedup            :", dedup.count())
print("silver total rows now  :", spark.table(SILVER).count())
display(spark.sql(f"SELECT reject_reason, count(*) AS n FROM {REJECTS} GROUP BY 1"))
display(spark.table(SILVER).orderBy(F.col("event_ts").desc()).limit(10))
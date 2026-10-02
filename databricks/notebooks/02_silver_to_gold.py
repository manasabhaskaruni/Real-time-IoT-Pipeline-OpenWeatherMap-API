# Databricks notebook source
# MAGIC %md
# MAGIC # 02 Silver to Gold
# MAGIC `weather_daily`: per city per day statistics (MERGE, so re-runs are safe).
# MAGIC `weather_rolling_7d`: 7-day rolling averages, weighted by the number of readings per day.

# COMMAND ----------
from datetime import datetime, timedelta
from delta.tables import DeltaTable
from pyspark.sql import Window
from pyspark.sql import functions as F

dbutils.widgets.text("lookback_days", "2")
lookback = int(dbutils.widgets.get("lookback_days"))
start_date = (datetime.utcnow() - timedelta(days=lookback)).strftime("%Y-%m-%d")

SILVER = "weather_iot.silver.weather_readings"
DAILY = "weather_iot.gold.weather_daily"
ROLL = "weather_iot.gold.weather_rolling_7d"

# COMMAND ----------
aqi_counts = [F.sum(F.when(F.col("aqi") == k, 1).otherwise(0)).cast("int").alias(f"readings_aqi_{k}") for k in range(1, 6)]

daily = (spark.table(SILVER)
    .filter(F.col("event_date") >= F.lit(start_date))
    .groupBy("city_id", "event_date")
    .agg(
        F.first("city").alias("city"), F.first("country").alias("country"),
        F.count(F.lit(1)).cast("int").alias("readings"),
        F.round(F.avg("temp_c"), 2).alias("avg_temp_c"),
        F.min("temp_c").alias("min_temp_c"), F.max("temp_c").alias("max_temp_c"),
        F.round(F.avg("humidity_pct"), 2).alias("avg_humidity_pct"),
        F.round(F.avg("pressure_hpa"), 2).alias("avg_pressure_hpa"),
        F.round(F.avg("wind_speed_ms"), 2).alias("avg_wind_speed_ms"),
        F.max("wind_speed_ms").alias("max_wind_speed_ms"),
        F.round(F.avg("aqi"), 2).alias("avg_aqi"), F.max("aqi").alias("max_aqi"),
        F.round(F.avg("pm2_5"), 2).alias("avg_pm2_5"), F.max("pm2_5").alias("max_pm2_5"),
        F.round(F.avg("pm10"), 2).alias("avg_pm10"),
        *aqi_counts)
    .withColumn("is_complete_day", F.col("event_date") < F.current_date())
    .withColumn("_gold_loaded_at", F.current_timestamp()))

(DeltaTable.forName(spark, DAILY).alias("t")
 .merge(daily.alias("s"), "t.city_id = s.city_id AND t.event_date = s.event_date")
 .whenMatchedUpdateAll()
 .whenNotMatchedInsertAll()
 .execute())

# COMMAND ----------
# 7-day rolling window (range of 6 days back plus today), weighted by readings per day
w7 = (Window.partitionBy("city_id")
      .orderBy(F.col("event_date").cast("timestamp").cast("long"))
      .rangeBetween(-6 * 86400, 0))

def weighted_avg(col):
    return F.round(F.sum(F.col(col) * F.col("readings")).over(w7) / F.sum("readings").over(w7), 2)

roll = (spark.table(DAILY).select(
    "city_id", "event_date",
    F.count(F.lit(1)).over(w7).cast("int").alias("days_in_window"),
    F.sum("readings").over(w7).cast("int").alias("readings_in_window"),
    weighted_avg("avg_temp_c").alias("roll7_avg_temp_c"),
    weighted_avg("avg_humidity_pct").alias("roll7_avg_humidity_pct"),
    weighted_avg("avg_pm2_5").alias("roll7_avg_pm2_5"),
    weighted_avg("avg_aqi").alias("roll7_avg_aqi"))
    .withColumn("_gold_loaded_at", F.current_timestamp()))

roll.write.format("delta").mode("overwrite").saveAsTable(ROLL)

# COMMAND ----------
display(spark.table(DAILY).orderBy("event_date", "city_id").limit(30))
display(spark.table(ROLL).orderBy(F.col("event_date").desc(), "city_id").limit(30))
# Databricks notebook source
# MAGIC %md
# MAGIC # 03 Maintenance
# MAGIC `OPTIMIZE` merges small files and `ZORDER` groups rows by the columns we filter on. `VACUUM` removes old unused files (7-day default).

# COMMAND ----------
TABLES = {
    "weather_iot.silver.weather_readings": "city_id, event_ts",
    "weather_iot.silver.weather_rejects": None,
    "weather_iot.gold.weather_daily": "city_id, event_date",
    "weather_iot.gold.weather_rolling_7d": "city_id, event_date",
}

for table, zorder in TABLES.items():
    sql = f"OPTIMIZE {table}" + (f" ZORDER BY ({zorder})" if zorder else "")
    print(sql)
    spark.sql(sql).select("path", "metrics.numFilesAdded", "metrics.numFilesRemoved").show(truncate=False)
    spark.sql(f"VACUUM {table}").show(truncate=False)
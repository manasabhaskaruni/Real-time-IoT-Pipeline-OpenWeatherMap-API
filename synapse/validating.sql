-- 1. Row counts: must equal the Databricks counts from step 1
SELECT COUNT(*) AS daily_rows   FROM gold.weather_daily;
SELECT COUNT(*) AS rolling_rows FROM gold.weather_rolling_7d;

-- 2. External table and OPENROWSET view agree
SELECT (SELECT COUNT(*) FROM gold.weather_daily)      AS external_table_rows,
       (SELECT COUNT(*) FROM adhoc.vw_weather_daily)  AS openrowset_rows;

-- 3. Column names and types as Synapse sees them (compare with DESCRIBE in Databricks)
EXEC sp_describe_first_result_set N'SELECT * FROM adhoc.vw_weather_daily';
EXEC sp_describe_first_result_set N'SELECT * FROM gold.weather_daily';

-- 4. Wrong column names return NULL silently. Every *_nn must equal total_rows.
SELECT COUNT(*) AS total_rows,
  COUNT(city_id) AS city_id_nn, COUNT(city) AS city_nn, COUNT(country) AS country_nn,
  COUNT(event_date) AS event_date_nn, COUNT(readings) AS readings_nn,
  COUNT(avg_temp_c) AS avg_temp_c_nn, COUNT(min_temp_c) AS min_temp_c_nn, COUNT(max_temp_c) AS max_temp_c_nn,
  COUNT(avg_humidity_pct) AS avg_humidity_nn, COUNT(avg_pressure_hpa) AS avg_pressure_nn,
  COUNT(avg_wind_speed_ms) AS avg_wind_nn, COUNT(max_wind_speed_ms) AS max_wind_nn,
  COUNT(avg_aqi) AS avg_aqi_nn, COUNT(max_aqi) AS max_aqi_nn,
  COUNT(avg_pm2_5) AS avg_pm25_nn, COUNT(max_pm2_5) AS max_pm25_nn, COUNT(avg_pm10) AS avg_pm10_nn,
  COUNT(readings_aqi_1) AS aqi1_nn, COUNT(readings_aqi_2) AS aqi2_nn, COUNT(readings_aqi_3) AS aqi3_nn,
  COUNT(readings_aqi_4) AS aqi4_nn, COUNT(readings_aqi_5) AS aqi5_nn,
  COUNT(is_complete_day) AS complete_nn
FROM gold.weather_daily;

SELECT COUNT(*) AS total_rows,
  COUNT(city_id) AS city_id_nn, COUNT(event_date) AS event_date_nn,
  COUNT(days_in_window) AS days_nn, COUNT(readings_in_window) AS readings_nn,
  COUNT(roll7_avg_temp_c) AS temp_nn, COUNT(roll7_avg_humidity_pct) AS humidity_nn,
  COUNT(roll7_avg_pm2_5) AS pm25_nn, COUNT(roll7_avg_aqi) AS aqi_nn
FROM gold.weather_rolling_7d;

-- 5. Coverage: expect 10 cities
SELECT city_id, city, COUNT(*) AS days, MIN(event_date) AS first_day, MAX(event_date) AS last_day
FROM gold.weather_daily GROUP BY city_id, city ORDER BY city_id;

-- 6. Sample rows and the air-quality story from Layer 4
SELECT TOP 20 * FROM gold.weather_rolling_7d ORDER BY event_date DESC, city_id;

SELECT city, AVG(avg_pm2_5) AS mean_pm25, SUM(readings_aqi_4 + readings_aqi_5) AS poor_readings
FROM gold.weather_daily GROUP BY city ORDER BY mean_pm25 DESC;
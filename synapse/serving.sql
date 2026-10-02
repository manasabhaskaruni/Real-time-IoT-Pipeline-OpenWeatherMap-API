-- Layer 5: serverless SQL serving layer over the gold Delta tables.
-- Safe to re-run. __STORAGE_ACCOUNT__ is replaced by 09-synapse.ps1.

IF DB_ID(N'weather_serving') IS NULL
    EXEC(N'CREATE DATABASE [weather_serving] COLLATE Latin1_General_100_BIN2_UTF8;');
GO

USE [weather_serving];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_scoped_credentials WHERE name = N'SynapseWorkspaceIdentity')
    CREATE DATABASE SCOPED CREDENTIAL [SynapseWorkspaceIdentity]
    WITH IDENTITY = 'Managed Identity';
GO

IF NOT EXISTS (SELECT 1 FROM sys.external_data_sources WHERE name = N'WeatherLake')
    CREATE EXTERNAL DATA SOURCE [WeatherLake]
    WITH (
        LOCATION = 'https://__STORAGE_ACCOUNT__.dfs.core.windows.net',
        CREDENTIAL = [SynapseWorkspaceIdentity]
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.external_file_formats WHERE name = N'DeltaLakeFormat')
    CREATE EXTERNAL FILE FORMAT [DeltaLakeFormat] WITH (FORMAT_TYPE = DELTA);
GO

IF SCHEMA_ID(N'gold') IS NULL EXEC(N'CREATE SCHEMA [gold];');
GO
IF SCHEMA_ID(N'adhoc') IS NULL EXEC(N'CREATE SCHEMA [adhoc];');
GO

-- Re-run safety: drop old objects so the definitions below always win
IF OBJECT_ID(N'gold.weather_daily', N'V') IS NOT NULL DROP VIEW [gold].[weather_daily];
IF OBJECT_ID(N'gold.weather_rolling_7d', N'V') IS NOT NULL DROP VIEW [gold].[weather_rolling_7d];
IF OBJECT_ID(N'gold.weather_daily', N'U') IS NOT NULL DROP EXTERNAL TABLE [gold].[weather_daily];
IF OBJECT_ID(N'gold.weather_rolling_7d', N'U') IS NOT NULL DROP EXTERNAL TABLE [gold].[weather_rolling_7d];
GO

CREATE EXTERNAL TABLE [gold].[weather_daily] (
    city_id varchar(32), city varchar(64), country varchar(2), event_date date,
    readings int,
    avg_temp_c float, min_temp_c float, max_temp_c float,
    avg_humidity_pct float, avg_pressure_hpa float,
    avg_wind_speed_ms float, max_wind_speed_ms float,
    avg_aqi float, max_aqi int,
    avg_pm2_5 float, max_pm2_5 float, avg_pm10 float,
    readings_aqi_1 int, readings_aqi_2 int, readings_aqi_3 int,
    readings_aqi_4 int, readings_aqi_5 int,
    is_complete_day bit
)
WITH (
    LOCATION = 'gold/weather_daily',
    DATA_SOURCE = [WeatherLake],
    FILE_FORMAT = [DeltaLakeFormat]
);
GO

CREATE EXTERNAL TABLE [gold].[weather_rolling_7d] (
    city_id varchar(32), event_date date,
    days_in_window int, readings_in_window int,
    roll7_avg_temp_c float, roll7_avg_humidity_pct float,
    roll7_avg_pm2_5 float, roll7_avg_aqi float
)
WITH (
    LOCATION = 'gold/weather_rolling_7d',
    DATA_SOURCE = [WeatherLake],
    FILE_FORMAT = [DeltaLakeFormat]
);
GO

-- OPENROWSET approach: schema inferred, no column list
CREATE OR ALTER VIEW [adhoc].[vw_weather_daily] AS
SELECT * FROM OPENROWSET(
    BULK 'gold/weather_daily',
    DATA_SOURCE = 'WeatherLake',
    FORMAT = 'DELTA'
) AS r;
GO

-- Dimension for Power BI slicers and relationships
CREATE OR ALTER VIEW [gold].[dim_city] AS
SELECT DISTINCT city_id, city, country FROM [gold].[weather_daily];
GO
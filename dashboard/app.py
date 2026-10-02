import os
from datetime import datetime, timezone

import pandas as pd
import streamlit as st
from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential

ENDPOINT = os.environ["COSMOS_ENDPOINT"]
DB_NAME = os.environ.get("COSMOS_DB", "weather")
AQI_LABEL = {1: "Good", 2: "Fair", 3: "Moderate", 4: "Poor", 5: "Very poor"}

st.set_page_config(page_title="Weather IoT hot path", layout="wide")
st.title("Weather IoT: live hot path")


@st.cache_resource
def containers():
    db = CosmosClient(ENDPOINT, credential=DefaultAzureCredential()).get_database_client(DB_NAME)
    return db.get_container_client("alerts"), db.get_container_client("city_metrics")


alerts_c, metrics_c = containers()


def pull_change_feed() -> int:
    """Read only what changed since the last pull (Cosmos DB Change Feed)."""
    token = st.session_state.get("cf_token")
    if token:
        feed = alerts_c.query_items_change_feed(continuation=token)
    else:
        feed = alerts_c.query_items_change_feed(is_start_from_beginning=True)
    docs = list(feed)
    st.session_state["cf_token"] = alerts_c.client_connection.last_response_headers.get("etag")
    store = st.session_state.setdefault("alerts", {})
    for d in docs:
        store[d["id"]] = d  # same id = same alert, so it overwrites
    return len(docs)


@st.fragment(run_every="10s")
def alerts_view():
    new = pull_change_feed()
    store = st.session_state.get("alerts", {})
    st.caption(f"Change Feed pull at {datetime.now(timezone.utc):%H:%M:%S} UTC: {new} new or updated alert(s)")
    if not store:
        st.info("No alerts yet.")
        return
    df = pd.DataFrame(store.values())
    df["alert_ts"] = pd.to_datetime(df["alert_ts"], utc=True)
    df = df.sort_values("alert_ts", ascending=False)
    recent = df[df["alert_ts"] >= pd.Timestamp.now(tz="UTC") - pd.Timedelta(hours=1)]

    c1, c2, c3 = st.columns(3)
    c1.metric("Alerts stored", len(df))
    c2.metric("Alerts in the last hour", len(recent))
    c3.metric("Cities affected (last hour)", recent["city_id"].nunique())

    left, right = st.columns([2, 1])
    left.dataframe(
        df[["alert_ts", "city_id", "alert_type", "severity", "metric",
            "metric_value", "threshold_value", "readings"]].head(50),
        hide_index=True,
    )
    right.bar_chart(df.groupby("city_id").size().rename("alerts"))


@st.fragment(run_every="10s")
def metrics_view():
    rows = list(metrics_c.query_items("SELECT * FROM c", enable_cross_partition_query=True))
    if not rows:
        st.info("No city metrics yet.")
        return
    df = pd.DataFrame(rows)
    latest = df[df["kind"] == "latest"].copy()
    roll = df[df["kind"] == "rolling60"].copy()

    st.subheader("Current conditions (latest reading per city)")
    latest["air_quality"] = latest["aqi"].map(lambda v: AQI_LABEL.get(int(v)) if pd.notna(v) else None)
    st.dataframe(
        latest[["city", "country", "temp_c", "feels_like_c", "humidity_pct", "wind_speed_ms",
                "weather_main", "aqi", "air_quality", "pm2_5", "ingest_ts"]].sort_values("city"),
        hide_index=True,
    )

    st.subheader("Rolling 60-minute averages")
    if roll.empty:
        st.info("Rolling averages appear after the first 10-minute window closes.")
        return
    a, b = st.columns(2)
    a.bar_chart(roll.set_index("city_id")["avg_temp_c"])
    b.bar_chart(roll.set_index("city_id")["avg_pm2_5"])
    st.dataframe(
        roll[["city_id", "window_end", "readings", "avg_temp_c", "avg_humidity_pct",
              "avg_pm2_5", "avg_aqi"]].sort_values("city_id"),
        hide_index=True,
    )


tab1, tab2 = st.tabs(["Live alerts (Change Feed)", "City metrics"])
with tab1:
    alerts_view()
with tab2:
    metrics_view()
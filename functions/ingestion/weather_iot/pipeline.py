import json
import logging
import time
from datetime import datetime, timezone
from pathlib import Path

import requests

from . import owm_call_api
from .publisher_to_event_hub import publish

CITIES_FILE = Path(__file__).resolve().parent.parent / "config" / "cities.json"
SCHEMA_VERSION = "1.0"
CALL_GAP_S = 0.25  # keeps us well under the 60 calls/min limit


def _iso(epoch: int) -> str:
    return datetime.fromtimestamp(epoch, tz=timezone.utc).isoformat().replace("+00:00", "Z")


def build_event(city: dict, w: dict, a: dict) -> dict:
    """Merge weather + air quality into one flat, enriched event (schema v1.0)."""
    main, wind = w.get("main", {}), w.get("wind", {})
    air = a["list"][0]
    comp = air["components"]
    return {
        "schema_version": SCHEMA_VERSION,
        "source": "openweathermap",
        "sensor_id": f"owm-{city['city_id']}",
        "city_id": city["city_id"],
        "city": city["city"],
        "country": city["country"],
        "lat": city["lat"],
        "lon": city["lon"],
        "event_ts": _iso(w["dt"]),
        "aq_event_ts": _iso(air["dt"]),
        "ingest_ts": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "temp_c": main.get("temp"),
        "feels_like_c": main.get("feels_like"),
        "humidity_pct": main.get("humidity"),
        "pressure_hpa": main.get("pressure"),
        "wind_speed_ms": wind.get("speed"),
        "wind_deg": wind.get("deg"),
        "clouds_pct": w.get("clouds", {}).get("all"),
        "visibility_m": w.get("visibility"),
        "weather_main": (w.get("weather") or [{}])[0].get("main"),
        "aqi": air["main"]["aqi"],
        "co": comp.get("co"), "no": comp.get("no"), "no2": comp.get("no2"),
        "o3": comp.get("o3"), "so2": comp.get("so2"),
        "pm2_5": comp.get("pm2_5"), "pm10": comp.get("pm10"), "nh3": comp.get("nh3"),
    }


def run() -> dict:
    cities = json.loads(CITIES_FILE.read_text(encoding="utf-8"))
    key = owm_call_api.get_api_key()
    session = owm_call_api.build_session()

    events, failed = [], []
    for c in cities:
        try:
            w = owm_call_api.fetch_weather(session, key, c["lat"], c["lon"])
            time.sleep(CALL_GAP_S)
            a = owm_call_api.fetch_air(session, key, c["lat"], c["lon"])
            time.sleep(CALL_GAP_S)
            events.append(build_event(c, w, a))
        except requests.HTTPError as e:
            logging.error("city=%s http_status=%s", c["city_id"], e.response.status_code)
            failed.append(c["city_id"])
        except Exception as e:  # type only: messages can contain the key
            logging.error("city=%s error=%s", c["city_id"], type(e).__name__)
            failed.append(c["city_id"])

    if events:
        publish(events, owm_call_api.get_credential())

    result = {"cities": len(cities), "published": len(events), "failed": failed}
    logging.info("poll complete: %s", result)
    return result
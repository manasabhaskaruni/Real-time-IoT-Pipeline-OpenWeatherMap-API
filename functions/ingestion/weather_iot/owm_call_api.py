import logging
import os
import time

import requests
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

BASE_URL = "https://api.openweathermap.org/data/2.5"
_SECRET_TTL_S = 3600
_cache = {"value": None, "fetched": 0.0}
_credential = None

# SECURITY: OpenWeatherMap only accepts the key in the URL query string.
# urllib3 logs URLs on retries, which would leak the key. Silence it.
logging.getLogger("urllib3").setLevel(logging.CRITICAL)


def get_credential():
    """Managed identity in Azure, `az login` on your laptop."""
    global _credential
    if _credential is None:
        _credential = DefaultAzureCredential()
    return _credential


def get_api_key() -> str:
    """Read the API key from Key Vault, cached for 1 hour."""
    now = time.monotonic()
    if _cache["value"] is None or now - _cache["fetched"] > _SECRET_TTL_S:
        client = SecretClient(vault_url=os.environ["KEY_VAULT_URL"], credential=get_credential())
        _cache["value"] = client.get_secret(os.environ.get("SECRET_NAME", "owm-api-key")).value
        _cache["fetched"] = now
        logging.info("API key loaded from Key Vault")
    return _cache["value"]


def build_session() -> requests.Session:
    retry = Retry(total=3, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504],
                  allowed_methods=["GET"])
    session = requests.Session()
    session.mount("https://", HTTPAdapter(max_retries=retry))
    return session


def _get(session, path, lat, lon, key):
    r = session.get(
        f"{BASE_URL}/{path}",
        params={"lat": lat, "lon": lon, "appid": key, "units": "metric"},
        timeout=10,
    )
    r.raise_for_status()
    return r.json()


def fetch_weather(session, key, lat, lon):
    return _get(session, "weather", lat, lon, key)


def fetch_air(session, key, lat, lon):
    return _get(session, "air_pollution", lat, lon, key)
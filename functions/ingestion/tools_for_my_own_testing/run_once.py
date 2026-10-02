'''runs the pipeline once from your laptop'''
import logging

from weather_iot.pipeline import run
logging.basicConfig(level=logging.WARNING)
logging.getLogger("weather_iot").setLevel(logging.INFO)
logging.getLogger().setLevel(logging.WARNING)
print(run())
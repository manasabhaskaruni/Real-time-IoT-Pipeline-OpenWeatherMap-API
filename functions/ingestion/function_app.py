'''the timer trigger Azure will run'''
import logging

import azure.functions as func

from weather_iot.pipeline import run

app = func.FunctionApp()
logging.basicConfig(level=logging.INFO)


@app.timer_trigger(schedule="%TIMER_SCHEDULE%", arg_name="timer",
                   run_on_startup=False, use_monitor=True)
def poll_weather(timer: func.TimerRequest) -> None:
    if timer.past_due:
        logging.warning("Timer is past due")
    result = run()
    if result["published"] == 0:
        raise RuntimeError("No events published this run")
    if result["failed"]:
        raise RuntimeError(f"Partial failure, {len(result['failed'])} city(ies) failed")
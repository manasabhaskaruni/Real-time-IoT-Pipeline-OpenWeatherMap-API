import json
import os

from azure.eventhub import EventHubConsumerClient
from azure.identity import DefaultAzureCredential

LIMIT = 3  # how many events to print
seen = 0

client = EventHubConsumerClient(
    fully_qualified_namespace=os.environ["EVENTHUB_FQDN"],
    eventhub_name=os.environ["EVENTHUB_NAME"],
    consumer_group="$Default",
    credential=DefaultAzureCredential(),
)


def on_event(ctx, event):
    global seen
    if event is None:
        return
    print(f"--- partition={ctx.partition_id} sequence={event.sequence_number} ---")
    print(json.dumps(json.loads(event.body_as_str()), indent=2))
    seen += 1
    if seen >= LIMIT:
        client.close()


with client:
    # Read the oldest retained events; a single partition is enough to see the shape
    client.receive(on_event=on_event, partition_id="0", starting_position="-1")
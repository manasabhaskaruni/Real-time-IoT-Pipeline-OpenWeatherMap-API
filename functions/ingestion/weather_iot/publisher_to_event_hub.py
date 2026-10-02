import json
import os

from azure.eventhub import EventData, EventHubProducerClient


def publish(events: list[dict], credential) -> None:
    """One event per city. city_id is the partition key, so a city always
    lands on the same partition and its events stay in order."""
    producer = EventHubProducerClient(
        fully_qualified_namespace=os.environ["EVENTHUB_FQDN"],
        eventhub_name=os.environ["EVENTHUB_NAME"],
        credential=credential,
    )
    with producer:
        for ev in events:
            batch = producer.create_batch(partition_key=ev["city_id"])
            data = EventData(json.dumps(ev, separators=(",", ":")))
            data.content_type = "application/json"
            batch.add(data)
            producer.send_batch(batch)
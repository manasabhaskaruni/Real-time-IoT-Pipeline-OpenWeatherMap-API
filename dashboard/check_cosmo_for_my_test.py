import os

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential

db = CosmosClient(os.environ["COSMOS_ENDPOINT"], credential=DefaultAzureCredential()).get_database_client("weather")

for name in ("alerts", "city_metrics"):
    c = db.get_container_client(name)
    n = list(c.query_items("SELECT VALUE COUNT(1) FROM c", enable_cross_partition_query=True))[0]
    ru = c.client_connection.last_response_headers.get("x-ms-request-charge")
    print(f"{name:13} documents={n:<4} count query cost={ru} RU")
    for d in c.query_items("SELECT TOP 2 * FROM c", enable_cross_partition_query=True):
        print("    ", {k: v for k, v in d.items() if not k.startswith("_")})
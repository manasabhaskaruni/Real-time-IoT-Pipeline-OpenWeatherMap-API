# Real-Time Weather IoT Pipeline

A five-layer Azure project that treats cities as virtual sensors. An Azure Function fetches weather and air-quality data from OpenWeatherMap, Event Hubs and Stream Analytics process the events, Databricks builds lakehouse tables, and Cosmos DB and Synapse serve live and historical data.

The project is deployed to Azure. Running the deployment scripts creates billable cloud resources, so review the scripts and Azure pricing before deploying.

## Project Layers

Each layer's document includes its design, deployment steps, and the outputs/evidence from this project.

| Layer | Purpose | Documentation |
|---|---|---|
| 1. Ingestion | Poll OpenWeatherMap and publish events to Event Hubs | [Layer 1: Ingestion](docs/layer_1.md) |
| 2. Stream processing | Save raw events, calculate rolling metrics, and detect anomalies | [Layer 2: Stream Processing](docs/layer2-stream-processing.md) |
| 3. Batch transformation | Clean and aggregate data with Databricks and Delta Lake | [Layer 3: Batch Transformation](docs/layer3-batch-processing.md) |
| 4. Hot-path serving | Send live alerts and metrics to Cosmos DB and display them in Streamlit | [Layer 4: Hot Path Serving](docs/layer4-hot-path.md) |
| 5. Cold-path serving | Query historical gold data through Synapse serverless SQL | [Layer 5: Cold Path Serving](docs/layer5-cold-path.md) |

## Before You Start

You will need:

- An Azure subscription with permission to create resources and assign the roles described in the layer docs.
- Azure CLI, PowerShell, Azure Functions Core Tools, and Python 3.11.
- A Databricks workspace and the Databricks CLI for the Layer 3 deployment.
- An OpenWeatherMap API key.
- Power BI Desktop if you want to connect to the Synapse views. Power BI Service features require an eligible work or school account.

The Azure scripts are PowerShell scripts under `infra/scripts/`. Review the relevant layer document before running them. They deploy real resources and may incur charges.

## Deploy to Your Azure Account

1. Clone this repository and open a PowerShell terminal in its root folder.
2. Sign in to Azure and select the subscription you intend to use:

   ```powershell
   az login
   az account set --subscription "<subscription-id>"
   ```

3. Follow [Layer 1](docs/layer_1.md) to create the foundation resources. For a new deployment, run `infra/scripts/00-foundation.ps1` first. It prints a region and a unique suffix.
4. Update `infra/scripts/env.ps1` with your region, suffix, resource names, and Databricks workspace URL. The checked-in values identify the original deployment and are not automatically unique for your account.
5. Run the layer deployment scripts in order, following each layer document:
   - Layer 1: `01-keyvault-eventhub.ps1`, then `02-function-app.ps1`
   - Layer 2: `03-stream-analytics.ps1`
   - Layer 3: `04-databricks.ps1`, `05-databricks-uc.ps1`, `06-databricks-deploy.ps1`, then `07-adf.ps1`
   - Layer 4: `08-cosmos.ps1`
   - Layer 5: `09-synapse.ps1`, then run the generated SQL in Synapse Studio as described in the layer document

Some layers also require setup in their Azure service portal. Follow the linked document for that layer rather than treating the scripts as a one-command deployment. Store the OpenWeatherMap key in Key Vault as `owm-api-key`; do not put it in source code or commit local settings files.

## Run the Local Dashboard

The Layer 4 Streamlit dashboard reads live data from your Cosmos DB account. First deploy Layer 4 and ensure your signed-in Azure identity has permission to read its containers. Then, from the repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r dashboard/requirements.txt
$env:COSMOS_ENDPOINT = "https://<your-cosmos-account>.documents.azure.com:443/"
az login
streamlit run dashboard/app.py
```

Keep `COSMOS_ENDPOINT` set in the terminal running Streamlit. The dashboard uses `DefaultAzureCredential`, so it authenticates with your Azure sign-in. The default database name is `weather`; override it with `$env:COSMOS_DB` if your deployment uses a different name.

## What Is Served

- **Live view:** Streamlit reads alerts and current city metrics from Cosmos DB. The project does not use Power BI to read the Cosmos Change Feed directly.
- **Historical reports:** Synapse serverless SQL exposes the gold Delta data for Power BI DirectQuery. See [Layer 5](docs/layer5-cold-path.md) for connection details.
- **Power BI push dataset:** The Layer 4 document explains the push-dataset limitation and the alternative implemented in this project.

## Repository Map

- `docs/` — detailed layer explanations, deployment instructions, and project evidence
- `functions/ingestion/` — timer-triggered Azure Function
- `streaming/` — Azure Stream Analytics query
- `databricks/` — Databricks Asset Bundle and notebooks
- `infra/` — Bicep templates and numbered PowerShell deployment scripts
- `dashboard/` — local Streamlit hot-path dashboard
- `synapse/` — SQL for historical serving and validation
- `powerbi/` — report measures
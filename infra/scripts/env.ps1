$sfx   = "gpwjq"
$loc   = "eastasia"
$floc  = $loc

$rg    = "rg-weather-iot-dev"
$law   = "log-weather-iot-dev"
$kv    = "kv-weather-$sfx"
$ehns  = "evhns-weather-$sfx"
$eh    = "weather-raw"
$fnstg = "stfn$sfx"
$fn    = "func-weather-ingest-$sfx"
$appi  = "appi-weather-iot"
$sa    = "stweatheriot$sfx"
$asa   = "asa-weather-$sfx"
$dbx   = "dbx-weather-$sfx"
$dbac  = "dbac-weather-$sfx"
$adf   = "adf-weather-$sfx"
$syn   = "syn-weather-$sfx"
$dbxhost = "https://adb-7405618529596716.16.azuredatabricks.net"    
if ($dbxhost) { $env:DATABRICKS_HOST = $dbxhost; $env:DATABRICKS_AUTH_TYPE = "azure-cli" }
$tags  = "project=weather-iot", "env=dev"
$me    = az ad signed-in-user show --query id -o tsv
$cosmos = "cosmos-weather-$sfx"

# Used only by local test scripts (endpoints, not secrets)
$env:KEY_VAULT_URL = "https://$kv.vault.azure.net/"
$env:SECRET_NAME   = "owm-api-key"
$env:EVENTHUB_FQDN = "$ehns.servicebus.windows.net"
$env:EVENTHUB_NAME = $eh
$env:COSMOS_ENDPOINT = "https://$cosmos.documents.azure.com:443/"
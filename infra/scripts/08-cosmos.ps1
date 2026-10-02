param([string]$CosmosLocation = "", [string]$Mode = "free")
. "$PSScriptRoot\env.ps1"
$cl = if ($CosmosLocation) { $CosmosLocation } else { $loc }

Write-Host "== Cosmos DB ($Mode, $cl) ==" -ForegroundColor Cyan
$out = az deployment group create --resource-group $rg `
  --template-file "$PSScriptRoot\..\bicep\cosmos.bicep" `
  --parameters accountName=$cosmos capacityMode=$Mode location=$cl `
  --query properties.outputs -o json | ConvertFrom-Json
if (-not $out) { Write-Host "Deployment failed. Paste me the error above." -ForegroundColor Red; return }

Write-Host "== Data-plane roles (no keys) ==" -ForegroundColor Cyan
$asaPrincipal = az stream-analytics job show --job-name $asa --resource-group $rg --query identity.principalId -o tsv
# 000...002 = Cosmos DB Built-in Data Contributor (ASA writes), 000...001 = Built-in Data Reader (me, dashboard)
az cosmosdb sql role assignment create --account-name $cosmos --resource-group $rg `
  --role-definition-id 00000000-0000-0000-0000-000000000002 --principal-id $asaPrincipal --scope "/" --output none
az cosmosdb sql role assignment create --account-name $cosmos --resource-group $rg `
  --role-definition-id 00000000-0000-0000-0000-000000000001 --principal-id $me --scope "/" --output none

Write-Host ""
Write-Host "SUCCESS" -ForegroundColor Green
Write-Host "  Endpoint : $($out.endpoint.value)"
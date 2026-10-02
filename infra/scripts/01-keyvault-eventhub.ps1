. "$PSScriptRoot\env.ps1"

Write-Host "== Key Vault ==" -ForegroundColor Cyan
az keyvault create --name $kv --resource-group $rg --location $loc `
  --enable-rbac-authorization true --retention-days 7 --tags $tags --output none
$kvid = az keyvault show --name $kv --resource-group $rg --query id -o tsv

az role assignment create --assignee-object-id $me --assignee-principal-type User `
  --role "Key Vault Secrets Officer" --scope $kvid --output none

Write-Host "== Event Hub namespace (Standard, Entra-only auth) ==" -ForegroundColor Cyan
az eventhubs namespace create --name $ehns --resource-group $rg --location $loc `
  --sku Standard --capacity 1 --disable-local-auth true --tags $tags --output none

Write-Host "== Event Hub: 4 partitions ==" -ForegroundColor Cyan
az eventhubs eventhub create --name $eh --namespace-name $ehns --resource-group $rg `
  --partition-count 4 --output none

Write-Host "== Consumer group for Stream Analytics (Layer 2) ==" -ForegroundColor Cyan
az eventhubs eventhub consumer-group create --name asa-cg --eventhub-name $eh `
  --namespace-name $ehns --resource-group $rg --output none

$ehid = az eventhubs eventhub show --name $eh --namespace-name $ehns --resource-group $rg --query id -o tsv
az role assignment create --assignee-object-id $me --assignee-principal-type User `
  --role "Azure Event Hubs Data Sender" --scope $ehid --output none
az role assignment create --assignee-object-id $me --assignee-principal-type User `
  --role "Azure Event Hubs Data Receiver" --scope $ehid --output none

Write-Host "Waiting 90s for role assignments to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 90
Write-Host "Done." -ForegroundColor Green
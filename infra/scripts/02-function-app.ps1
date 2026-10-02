. "$PSScriptRoot\env.ps1"

Write-Host "== Function host storage ==" -ForegroundColor Cyan
az storage account create --name $fnstg --resource-group $rg --location $floc `
  --sku Standard_LRS --kind StorageV2 --allow-blob-public-access false `
  --min-tls-version TLS1_2 --tags $tags --output none

Write-Host "== Application Insights (linked to Log Analytics) ==" -ForegroundColor Cyan
$lawid = az monitor log-analytics workspace show --resource-group $rg --workspace-name $law --query id -o tsv
az monitor app-insights component create --app $appi --location $floc --resource-group $rg `
  --workspace $lawid --kind web --application-type web --tags $tags --output none

Write-Host "== Function App (Flex Consumption, Python 3.11) ==" -ForegroundColor Cyan
az functionapp create --name $fn --resource-group $rg --flexconsumption-location $floc `
  --runtime python --runtime-version 3.11 --storage-account $fnstg `
  --app-insights $appi --output none

Write-Host "== System-assigned managed identity ==" -ForegroundColor Cyan
az functionapp identity assign --name $fn --resource-group $rg --output none
$fnPrincipal = az functionapp identity show --name $fn --resource-group $rg --query principalId -o tsv

Write-Host "== Least-privilege roles ==" -ForegroundColor Cyan
$kvid = az keyvault show --name $kv --resource-group $rg --query id -o tsv
$ehid = az eventhubs eventhub show --name $eh --namespace-name $ehns --resource-group $rg --query id -o tsv
az role assignment create --assignee-object-id $fnPrincipal --assignee-principal-type ServicePrincipal `
  --role "Key Vault Secrets User" --scope $kvid --output none
az role assignment create --assignee-object-id $fnPrincipal --assignee-principal-type ServicePrincipal `
  --role "Azure Event Hubs Data Sender" --scope $ehid --output none

Write-Host "== App settings (endpoints only, no secrets) ==" -ForegroundColor Cyan
az functionapp config appsettings set --name $fn --resource-group $rg --output none --settings `
  "KEY_VAULT_URL=https://$kv.vault.azure.net/" `
  "SECRET_NAME=owm-api-key" `
  "EVENTHUB_FQDN=$ehns.servicebus.windows.net" `
  "EVENTHUB_NAME=$eh" `
  "TIMER_SCHEDULE=0 */10 * * * *"

Write-Host "Waiting 90s for role assignments to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 90
Write-Host "Done." -ForegroundColor Green
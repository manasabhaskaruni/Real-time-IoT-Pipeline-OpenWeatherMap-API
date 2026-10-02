. "$PSScriptRoot\env.ps1"

Write-Host "== Lake access for me + containers ==" -ForegroundColor Cyan
$said = az storage account show --name $sa --resource-group $rg --query id -o tsv
az role assignment create --assignee-object-id $me --assignee-principal-type User `
  --role "Storage Blob Data Contributor" --scope $said --output none
Write-Host "Waiting 60s for the role..." -ForegroundColor Yellow
Start-Sleep -Seconds 60
foreach ($c in "bronze","silver","gold","stream-out") {
  az storage container create --account-name $sa --name $c --auth-mode login --output none
}

Write-Host "== Deploy Stream Analytics job ==" -ForegroundColor Cyan
$principal = az deployment group create --resource-group $rg `
  --template-file "$PSScriptRoot\..\bicep\stream-analytics.bicep" `
  --parameters jobName=$asa eventHubNamespace=$ehns eventHubName=$eh storageAccountName=$sa location=$loc `
  --query properties.outputs.principalId.value -o tsv
if (-not $principal) { Write-Host "Deployment failed. Paste me the error above." -ForegroundColor Red; return }

Write-Host "== Roles for the job's managed identity ==" -ForegroundColor Cyan
$ehid = az eventhubs eventhub show --name $eh --namespace-name $ehns --resource-group $rg --query id -o tsv
az role assignment create --assignee-object-id $principal --assignee-principal-type ServicePrincipal `
  --role "Azure Event Hubs Data Receiver" --scope $ehid --output none
az role assignment create --assignee-object-id $principal --assignee-principal-type ServicePrincipal `
  --role "Storage Blob Data Contributor" --scope $said --output none

Write-Host "Waiting 90s for role assignments to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 90
Write-Host "Done. Job is created but NOT started." -ForegroundColor Green
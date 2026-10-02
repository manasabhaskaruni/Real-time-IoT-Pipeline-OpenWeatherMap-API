. "$PSScriptRoot\env.ps1"
az extension add --name datafactory --yes 2>$null

$subid = az account show --query id -o tsv
$wsid = "/subscriptions/$subid/resourceGroups/$rg/providers/Microsoft.Databricks/workspaces/$dbx"

Write-Host "== Find the Databricks job ==" -ForegroundColor Cyan
$jobs = (databricks jobs list -o json | ConvertFrom-Json)
$job = $jobs | Where-Object { $_.settings.name -eq "weather-daily-batch" } | Select-Object -First 1
if (-not $job) { Write-Host "Job weather-daily-batch not found. Deploy it first (06 script)." -ForegroundColor Red; return }
$jobId = [string]$job.job_id
Write-Host "Job id: $jobId"

Write-Host "== Stop the trigger if it exists (a started trigger cannot be updated) ==" -ForegroundColor Cyan
az datafactory trigger stop --factory-name $adf --resource-group $rg --name tr_daily_0100_utc 2>$null | Out-Null

Write-Host "== Deploy Data Factory ==" -ForegroundColor Cyan
$start = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddT00:00:00Z")
$principal = az deployment group create --resource-group $rg `
  --template-file "$PSScriptRoot\..\bicep\adf.bicep" `
  --parameters factoryName=$adf workspaceUrl=$dbxhost workspaceResourceId=$wsid jobId=$jobId startTime=$start location=$loc `
  --query properties.outputs.principalId.value -o tsv
if (-not $principal) { Write-Host "Deployment failed. Paste me the error above." -ForegroundColor Red; return }

Write-Host "== Let the ADF identity call the Databricks workspace ==" -ForegroundColor Cyan
az role assignment create --assignee-object-id $principal --assignee-principal-type ServicePrincipal `
  --role "Contributor" --scope $wsid --output none
Write-Host "Waiting 90s for the role to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 90

Write-Host "== Start the daily trigger ==" -ForegroundColor Cyan
az datafactory trigger start --factory-name $adf --resource-group $rg --name tr_daily_0100_utc

Write-Host "Done. Trigger state:" -ForegroundColor Green
az datafactory trigger show --factory-name $adf --resource-group $rg --name tr_daily_0100_utc --query properties.runtimeState -o tsv
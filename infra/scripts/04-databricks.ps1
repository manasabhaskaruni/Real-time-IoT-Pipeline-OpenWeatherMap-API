. "$PSScriptRoot\env.ps1"

Write-Host "== Databricks workspace (Premium) + access connector ==" -ForegroundColor Cyan
$out = az deployment group create --resource-group $rg `
  --template-file "$PSScriptRoot\..\bicep\databricks.bicep" `
  --parameters workspaceName=$dbx connectorName=$dbac location=$loc `
  --query properties.outputs -o json | ConvertFrom-Json
if (-not $out) { Write-Host "Deployment failed. Paste me the error above." -ForegroundColor Red; return }

Write-Host "== Connector may read/write the data lake ==" -ForegroundColor Cyan
$said = az storage account show --name $sa --resource-group $rg --query id -o tsv
az role assignment create --assignee-object-id $out.connectorPrincipalId.value --assignee-principal-type ServicePrincipal `
  --role "Storage Blob Data Contributor" --scope $said --output none

az storage container create --account-name $sa --name uc-managed --auth-mode login --output none

Write-Host "Waiting 90s for the role to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 90

Write-Host ""
Write-Host "SUCCESS" -ForegroundColor Green
Write-Host "  Workspace URL : https://$($out.workspaceUrl.value)"
Write-Host "Copy the URL into env.ps1 as `$dbxhost."
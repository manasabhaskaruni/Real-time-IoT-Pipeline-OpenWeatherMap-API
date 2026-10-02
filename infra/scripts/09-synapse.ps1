param([string]$SynapseLocation = '')
. "$PSScriptRoot\env.ps1"

$sloc = if ($SynapseLocation) { $SynapseLocation } else { $loc }
$template = Join-Path $PSScriptRoot '..\bicep\synapse.bicep'

Write-Host '== Register resource providers ==' -ForegroundColor Cyan
az provider register --namespace Microsoft.Synapse --wait
az provider register --namespace Microsoft.Sql --wait

$adminLogin = az ad signed-in-user show --query userPrincipalName -o tsv
if (-not $adminLogin) { throw 'Could not resolve the signed-in Entra user for the Synapse SQL administrator.' }
$myIp = (Invoke-RestMethod https://api.ipify.org)

$parameters = @(
  "workspaceName=$syn"
  "storageAccountName=$sa"
  'filesystemName=synapse'
  "adminObjectId=$me"
  "adminLogin=$adminLogin"
  "clientIp=$myIp"
  "location=$sloc"
)

Write-Host "== Synapse workspace and serverless SQL ($sloc) ==" -ForegroundColor Cyan
Write-Host '== Preview infrastructure changes ==' -ForegroundColor Cyan
az deployment group what-if --resource-group $rg --template-file $template --parameters @parameters
if ($LASTEXITCODE -ne 0) { throw 'Synapse what-if validation failed; deployment was not started.' }

Write-Host '== Deploy Synapse serverless workspace ==' -ForegroundColor Cyan
$outputsJson = az deployment group create --resource-group $rg --template-file $template `
  --parameters @parameters --query properties.outputs -o json
if ($LASTEXITCODE -ne 0 -or -not $outputsJson) { throw 'Synapse deployment failed.' }
$outputs = $outputsJson | ConvertFrom-Json

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sqlTemplate = Get-Content -LiteralPath (Join-Path $repoRoot 'synapse\serving.sql') -Raw
$resolvedSql = $sqlTemplate.Replace('__STORAGE_ACCOUNT__', $sa)
$generatedDirectory = Join-Path $repoRoot '.azure'
New-Item -ItemType Directory -Path $generatedDirectory -Force | Out-Null
$generatedSql = Join-Path $generatedDirectory 'weather-serving.sql'
[System.IO.File]::WriteAllText($generatedSql, $resolvedSql, (New-Object System.Text.UTF8Encoding $false))

Write-Host ''
Write-Host 'SUCCESS' -ForegroundColor Green
Write-Host "  Workspace       : $syn"
Write-Host "  Serverless SQL  : $($outputs.sqlOnDemandEndpoint.value)"
Write-Host '  Database        : weather_serving'
Write-Host "  SQL setup file  : $generatedSql"
Write-Host '  Studio          : https://web.azuresynapse.net'
Write-Host 'Run the generated SQL in Synapse Studio against the serverless Built-in pool.' -ForegroundColor Yellow
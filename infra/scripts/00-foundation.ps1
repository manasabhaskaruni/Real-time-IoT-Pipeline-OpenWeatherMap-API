$rg  = "rg-weather-iot-dev"
$law = "log-weather-iot-dev"
$regions = "centralindia","southindia","westindia","southeastasia","eastasia","uaenorth","westeurope","northeurope","uksouth","swedencentral"

$chosen = $null
foreach ($r in $regions) {
  Write-Host "Trying $r ..." -ForegroundColor Cyan
  az group create --name $rg --location $r --tags project=weather-iot env=dev --output none 2>$null
  if ($LASTEXITCODE -ne 0) { Write-Host "  resource group blocked in $r" -ForegroundColor Yellow; continue }

  az monitor log-analytics workspace create --resource-group $rg --workspace-name $law --location $r --sku PerGB2018 --output none 2>$null
  if ($LASTEXITCODE -eq 0) { $chosen = $r; break }

  Write-Host "  workspace blocked in $r, cleaning up" -ForegroundColor Yellow
  az group delete --name $rg --yes --output none
}

if (-not $chosen) { Write-Host "No region worked. Paste me the output of: az group create --name test-rg --location centralindia" -ForegroundColor Red; return }

$sfx = -join ((97..122) | Get-Random -Count 5 | ForEach-Object { [char]$_ })
$sa  = "stweatheriot$sfx"

Write-Host "Creating data lake storage $sa in $chosen ..." -ForegroundColor Cyan
az storage account create --name $sa --resource-group $rg --location $chosen --sku Standard_LRS --kind StorageV2 `
  --enable-hierarchical-namespace true --allow-blob-public-access false --min-tls-version TLS1_2 `
  --tags project=weather-iot env=dev --output none
if ($LASTEXITCODE -ne 0) { Write-Host "Storage creation failed. Paste me the error." -ForegroundColor Red; return }

Write-Host ""
Write-Host "SUCCESS" -ForegroundColor Green
Write-Host "  Region : $chosen"
Write-Host "  Suffix : $sfx"
Write-Host "Write these two values down. They go into env.ps1."
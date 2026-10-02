. "$PSScriptRoot\env.ps1"
$subid = az account show --query id -o tsv
$connectorId = "/subscriptions/$subid/resourceGroups/$rg/providers/Microsoft.Databricks/accessConnectors/$dbac"

Write-Host "== Storage credential (via access connector) ==" -ForegroundColor Cyan
$tmp = Join-Path $env:TEMP "sc-weather.json"
@{ name = "sc-weather"
   azure_managed_identity = @{ access_connector_id = $connectorId }
   comment = "Access connector for the weather lake" } |
  ConvertTo-Json -Depth 5 | Set-Content -Path $tmp -Encoding ascii
databricks storage-credentials create --json "@$tmp"
Remove-Item $tmp

foreach ($c in "bronze","silver","gold","uc-managed") {
  $name = "el_" + $c.Replace("-","_")
  Write-Host "== External location $name ==" -ForegroundColor Cyan
  databricks external-locations create $name "abfss://$c@$sa.dfs.core.windows.net/" sc-weather
}

Write-Host "== Result ==" -ForegroundColor Green
databricks external-locations list
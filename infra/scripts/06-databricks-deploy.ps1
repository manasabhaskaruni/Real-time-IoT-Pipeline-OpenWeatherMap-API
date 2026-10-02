param([string]$NodeType = "")
. "$PSScriptRoot\env.ps1"

$versions = (databricks clusters spark-versions -o json | ConvertFrom-Json).versions
$ver = ($versions |
  Where-Object { $_.name -match "LTS" -and $_.name -cnotmatch "ML|GPU|Photon|Beta|aarch64" -and $_.key -match '^\d+\.\d+\.x-scala' } |
  Sort-Object { [version](($_.key -split "\.x")[0] + ".0") } -Descending |
  Select-Object -First 1).key

$types = (databricks clusters list-node-types -o json | ConvertFrom-Json).node_types.node_type_id
$candidates = "Standard_D4s_v3","Standard_D4ds_v4","Standard_D4as_v4","Standard_E4s_v3","Standard_E4ds_v4","Standard_F4s_v2","Standard_DS3_v2"
if ($NodeType) { $node = $NodeType }
else { $node = $candidates | Where-Object { $types -contains $_ } | Select-Object -First 1 }

if (-not $ver -or -not $node) { Write-Host "Could not pick a runtime or node type. Paste me this message." -ForegroundColor Red; return }
Write-Host "Runtime: $ver   Node type: $node" -ForegroundColor Cyan

Push-Location "$PSScriptRoot\..\..\databricks"
databricks bundle deploy -t dev --var "spark_version=$ver" --var "node_type_id=$node"
Pop-Location
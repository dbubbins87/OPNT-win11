$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Out = Join-Path $Root 'dist'
$Stage = Join-Path $Out 'OperationNeptune-Win11-Patch-1.0.1'
$Zip = Join-Path $Out 'OperationNeptune-Win11-Patch-1.0.1.zip'

if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $Stage 'patches') -Force | Out-Null

Copy-Item (Join-Path $Root 'NeptunePatch.ps1') $Stage
Copy-Item (Join-Path $Root 'NeptunePatch.cmd') $Stage
Copy-Item (Join-Path $Root 'LICENSE') (Join-Path $Stage 'LICENSE.txt')
Copy-Item (Join-Path $Root 'docs\RELEASE_NOTES.md') (Join-Path $Stage 'README.txt')
Copy-Item (Join-Path $Root 'patches\opnep_2x_scaler.bin') (Join-Path $Stage 'patches\opnep_2x_scaler.bin')
Copy-Item (Join-Path $Root 'patches\known-builds.json') (Join-Path $Stage 'patches\known-builds.json')

Compress-Archive -Path "$Stage\*" -DestinationPath $Zip -CompressionLevel Optimal
Write-Host "Created $Zip"

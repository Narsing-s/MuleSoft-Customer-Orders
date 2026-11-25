$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
$runner = Join-Path $repoRoot 'run_generator_scheduled.ps1'
$taskName = 'MuleSoftCustomerOrdersFileGenerator'
if (-not (Test-Path $runner)) { throw "Generator runner not found: $runner" }
$taskCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $runner + '"'
& schtasks.exe /Create /SC MINUTE /MO 2 /TN $taskName /TR $taskCommand /F
if ($LASTEXITCODE -ne 0) { throw 'Windows Task Scheduler could not create the two-minute task.' }
Write-Host "Installed task '$taskName'."
Write-Host 'Excel and XML files will be regenerated every 2 minutes.'
Write-Host 'Input folder: C:\Users\91938\Desktop\mulesoft file processing input data'
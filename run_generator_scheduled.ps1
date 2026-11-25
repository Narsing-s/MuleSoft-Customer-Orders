$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
$generatorDir = Join-Path $repoRoot 'generator'
$logFile = Join-Path $generatorDir 'generator.log'
try {
    Set-Location $generatorDir
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting file generation." | Out-File -FilePath $logFile -Append -Encoding utf8
    & python.exe (Join-Path $generatorDir 'generate_all.py') *>> $logFile
    if ($LASTEXITCODE -ne 0) { throw "Python generator exited with code $LASTEXITCODE" }
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Generation completed." | Out-File -FilePath $logFile -Append -Encoding utf8
} catch {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: $($_.Exception.Message)" | Out-File -FilePath $logFile -Append -Encoding utf8
    exit 1
}
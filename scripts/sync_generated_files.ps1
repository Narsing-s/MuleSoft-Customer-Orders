param(
    [switch]$Install,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
$taskName = 'MuleSoftCustomerOrdersCloudSync'
$inputFolder = 'C:\Users\91938\Desktop\mulesoft file processing input data'
$logFolder = Join-Path $env:LOCALAPPDATA 'MuleSoftCustomerOrders'
$logFile = Join-Path $logFolder 'cloud-sync.log'
$stateFile = Join-Path $logFolder 'last-synced-hashes.json'
$baseUrl = 'https://raw.githubusercontent.com/Narsing-s/MuleSoft-Customer-Orders/main/generated-files'

New-Item -ItemType Directory -Path $inputFolder -Force | Out-Null
New-Item -ItemType Directory -Path $logFolder -Force | Out-Null

function Write-Log([string]$Message) {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" |
        Out-File -FilePath $logFile -Append -Encoding utf8
}

function Test-Xlsx([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $signature = New-Object byte[] 2
        [void]$stream.Read($signature, 0, 2)
        return ($signature[0] -eq 0x50 -and $signature[1] -eq 0x4B)
    } finally {
        $stream.Dispose()
    }
}

function Test-Xml([string]$Path) {
    [xml]$document = Get-Content -LiteralPath $Path -Raw
    return ($document.DocumentElement.LocalName -eq 'CustomerOrders')
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}


function Invoke-DownloadWithRetry([string]$Uri, [string]$OutFile, [int]$MaxAttempts = 4) {
    $delays = @(5, 10, 20, 30)
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            # Remove only an incomplete temporary download in the app's log folder.
            if (Test-Path -LiteralPath $OutFile) {
                Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            }
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -TimeoutSec 90 -ErrorAction Stop
            if (-not (Test-Path -LiteralPath $OutFile) -or (Get-Item -LiteralPath $OutFile).Length -lt 20) {
                throw "Download was empty or incomplete: $Uri"
            }
            return
        } catch {
            $message = $_.Exception.Message
            if (Test-Path -LiteralPath $OutFile) {
                Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            }
            if ($attempt -ge $MaxAttempts) {
                throw "Download failed after $MaxAttempts attempts: $Uri. Last error: $message"
            }
            $delay = $delays[$attempt - 1]
            Write-Log "Download attempt $attempt/$MaxAttempts failed for $Uri: $message. Retrying in $delay seconds."
            Start-Sleep -Seconds $delay
        }
    }
}

function Invoke-DownloadWithRetry([string]$Uri, [string]$OutFile, [int]$MaxAttempts = 4) {
    $delays = @(5, 10, 20, 30)
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            # Clean up only this script's temporary download in the local app-data folder.
            if (Test-Path -LiteralPath $OutFile) {
                Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            }
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -TimeoutSec 90 -ErrorAction Stop
            if (-not (Test-Path -LiteralPath $OutFile) -or (Get-Item -LiteralPath $OutFile).Length -lt 20) {
                throw "Download was empty or incomplete: $Uri"
            }
            return
        } catch {
            $message = $_.Exception.Message
            if (Test-Path -LiteralPath $OutFile) {
                Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            }
            if ($attempt -ge $MaxAttempts) {
                throw "Download failed after $MaxAttempts attempts: $Uri. Last error: $message"
            }
            $delay = $delays[$attempt - 1]
            Write-Log "Download attempt $attempt/$MaxAttempts failed for $Uri: $message. Retrying in $delay seconds."
            Start-Sleep -Seconds $delay
        }
    }
}

if ($Install) {
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { throw 'Could not determine the installed sync script path.' }
    $powerShellExe = Join-Path $PSHOME 'powershell.exe'
    $taskCommand = '"' + $powerShellExe + '" -NoProfile -ExecutionPolicy Bypass -File "' + $scriptPath + '" -Run'
    & "$env:WINDIR\System32\schtasks.exe" /Create /SC MINUTE /MO 5 /TN $taskName /TR $taskCommand /F
    if ($LASTEXITCODE -ne 0) { throw 'Could not register the five-minute Windows scheduled task.' }
    Write-Log "Installed scheduled sync. Destination: $inputFolder"
    & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Run
    if ($LASTEXITCODE -ne 0) { throw 'Initial sync failed. See cloud-sync.log.' }
    Write-Host "Automatic cloud-to-PC sync installed. New timestamped files are saved directly to: $inputFolder"
    Write-Host 'Existing files are never overwritten or deleted.'
    exit 0
}

$downloads = @()
try {
    $xlsxTemp = Join-Path $logFolder 'customers_orders.xlsx.download'
    $xmlTemp = Join-Path $logFolder 'customers_orders.xml.download'
    $downloads = @($xlsxTemp, $xmlTemp)

    Invoke-DownloadWithRetry -Uri "$baseUrl/customers_orders.xlsx" -OutFile $xlsxTemp
    Invoke-DownloadWithRetry -Uri "$baseUrl/customers_orders.xml" -OutFile $xmlTemp

    foreach ($path in $downloads) {
        if (-not (Test-Path $path) -or (Get-Item $path).Length -lt 20) {
            throw "Downloaded file is missing or too small: $path"
        }
    }
    if (-not (Test-Xlsx $xlsxTemp)) {
        throw 'Downloaded XLSX is not a valid ZIP-based workbook.'
    }
    if (-not (Test-Xml $xmlTemp)) {
        throw 'Downloaded XML does not have the expected CustomerOrders root.'
    }

    $xlsxHash = Get-Sha256 $xlsxTemp
    $xmlHash = Get-Sha256 $xmlTemp
    $previous = $null
    if (Test-Path $stateFile) {
        try { $previous = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json } catch { $previous = $null }
    }

    if ($previous -and $previous.xlsx -eq $xlsxHash -and $previous.xml -eq $xmlHash) {
        Write-Log 'No new cloud file version. Existing local files were left untouched.'
        Write-Host 'No new version found. All existing files were left untouched.'
        exit 0
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $xlsxName = "customers_orders_$stamp.xlsx"
    $xmlName = "customers_orders_$stamp.xml"
    $xlsxDestination = Join-Path $inputFolder $xlsxName
    $xmlDestination = Join-Path $inputFolder $xmlName

    $suffix = 1
    while ((Test-Path $xlsxDestination) -or (Test-Path $xmlDestination)) {
        $candidate = "{0}_{1:D2}" -f $stamp, $suffix
        $xlsxName = "customers_orders_$candidate.xlsx"
        $xmlName = "customers_orders_$candidate.xml"
        $xlsxDestination = Join-Path $inputFolder $xlsxName
        $xmlDestination = Join-Path $inputFolder $xmlName
        $suffix++
    }

    # Move only newly downloaded temporary files to fresh, uniquely named files.
    # No existing destination file or folder is overwritten, moved, or deleted.
    [System.IO.File]::Move($xlsxTemp, $xlsxDestination)
    [System.IO.File]::Move($xmlTemp, $xmlDestination)

    $state = [ordered]@{ xlsx = $xlsxHash; xml = $xmlHash; savedAt = (Get-Date).ToString('o') }
    $state | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8

    Write-Log "SUCCESS: saved new version as $xlsxName and $xmlName in $inputFolder. Existing files preserved."
    Write-Host "Saved new files: $xlsxName and $xmlName"
    Write-Host "Destination: $inputFolder"
    Write-Host 'All previous files and folders were preserved.'
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    foreach ($path in $downloads) {
        if ($path -and (Test-Path $path)) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }
    exit 1
}

param(
    [switch]$Install,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
$taskName = 'MuleSoftCustomerOrdersCloudSync'
$inputFolder = 'C:\Users\91938\Desktop\mulesoft file processing input data'
$archiveFolder = Join-Path $inputFolder 'archive'
$logFolder = Join-Path $env:LOCALAPPDATA 'MuleSoftCustomerOrders'
$logFile = Join-Path $logFolder 'cloud-sync.log'
$baseUrl = 'https://raw.githubusercontent.com/Narsing-s/MuleSoft-Customer-Orders/main/generated-files'
$files = @('customers_orders.xlsx', 'customers_orders.xml')

New-Item -ItemType Directory -Path $inputFolder -Force | Out-Null
New-Item -ItemType Directory -Path $archiveFolder -Force | Out-Null
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

function Download-AndValidate([string]$Url, [string]$Destination, [string]$Kind) {
    $temp = $Destination + '.download'
    Invoke-WebRequest -Uri $Url -OutFile $temp -UseBasicParsing -TimeoutSec 60
    if (-not (Test-Path $temp) -or (Get-Item $temp).Length -lt 20) {
        throw "Downloaded file is missing or too small: $Url"
    }
    if ($Kind -eq 'xlsx' -and -not (Test-Xlsx $temp)) {
        throw "Downloaded XLSX is not a valid ZIP-based workbook: $Url"
    }
    if ($Kind -eq 'xml' -and -not (Test-Xml $temp)) {
        throw "Downloaded XML does not have the expected CustomerOrders root: $Url"
    }
    Move-Item -LiteralPath $temp -Destination $Destination -Force
}

if ($Install) {
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { throw 'Could not determine the installed sync script path.' }
    $powerShellExe = Join-Path $PSHOME 'powershell.exe'
    $taskCommand = '"' + $powerShellExe + '" -NoProfile -ExecutionPolicy Bypass -File "' + $scriptPath + '" -Run'
    & "$env:WINDIR\System32\schtasks.exe" /Create /SC MINUTE /MO 2 /TN $taskName /TR $taskCommand /F
    if ($LASTEXITCODE -ne 0) { throw 'Could not register the two-minute Windows scheduled task.' }
    Write-Log "Installed scheduled sync. Destination: $inputFolder"
    & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Run
    if ($LASTEXITCODE -ne 0) { throw 'Initial sync failed. See cloud-sync.log.' }
    Write-Host "Automatic cloud-to-PC sync installed. Files are saved to: $inputFolder"
    Write-Host 'The task checks GitHub every 2 minutes and recovers all missed archive versions.'
    exit 0
}

try {
    # Always refresh the current/latest pair.
    Download-AndValidate "$baseUrl/customers_orders.xlsx" (Join-Path $inputFolder 'customers_orders.xlsx') 'xlsx'
    Download-AndValidate "$baseUrl/customers_orders.xml" (Join-Path $inputFolder 'customers_orders.xml') 'xml'

    # The manifest lists every cloud generation. Missing pairs are fetched after
    # the PC reconnects, so versions created while it was offline are recovered.
    $manifestTemp = Join-Path $archiveFolder 'manifest.json.download'
    Invoke-WebRequest -Uri "$baseUrl/archive/manifest.json" -OutFile $manifestTemp -UseBasicParsing -TimeoutSec 60
    $manifest = Get-Content -LiteralPath $manifestTemp -Raw | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1 -or $null -eq $manifest.versions) {
        throw 'Archive manifest has an unsupported or invalid structure.'
    }

    $recovered = 0
    foreach ($version in $manifest.versions) {
        if ($version.id -notmatch '^\d{8}T\d{12}Z$') {
            throw "Invalid archive version identifier in manifest: $($version.id)"
        }
        $xlsxName = "customers_orders_$($version.id).xlsx"
        $xmlName = "customers_orders_$($version.id).xml"
        if ([System.IO.Path]::GetFileName([string]$version.xlsx) -ne $xlsxName -or
            [System.IO.Path]::GetFileName([string]$version.xml) -ne $xmlName) {
            throw "Unsafe or unexpected archive filename in manifest for version $($version.id)"
        }

        $localXlsx = Join-Path $archiveFolder $xlsxName
        $localXml = Join-Path $archiveFolder $xmlName
        if ((Test-Path $localXlsx) -and (Test-Path $localXml)) { continue }

        # Download and validate both members before considering this version complete.
        $tempXlsx = $localXlsx + '.download'
        $tempXml = $localXml + '.download'
        try {
            Invoke-WebRequest -Uri "$baseUrl/$($version.xlsx)" -OutFile $tempXlsx -UseBasicParsing -TimeoutSec 60
            Invoke-WebRequest -Uri "$baseUrl/$($version.xml)" -OutFile $tempXml -UseBasicParsing -TimeoutSec 60
            if (-not (Test-Path $tempXlsx) -or -not (Test-Xlsx $tempXlsx)) {
                throw "Archive XLSX validation failed for version $($version.id)"
            }
            if (-not (Test-Path $tempXml) -or -not (Test-Xml $tempXml)) {
                throw "Archive XML validation failed for version $($version.id)"
            }
            Move-Item -LiteralPath $tempXlsx -Destination $localXlsx -Force
            Move-Item -LiteralPath $tempXml -Destination $localXml -Force
            $recovered++
        } finally {
            if (Test-Path $tempXlsx) { Remove-Item -LiteralPath $tempXlsx -Force -ErrorAction SilentlyContinue }
            if (Test-Path $tempXml) { Remove-Item -LiteralPath $tempXml -Force -ErrorAction SilentlyContinue }
        }
    }

    Move-Item -LiteralPath $manifestTemp -Destination (Join-Path $archiveFolder 'manifest.json') -Force
    Write-Log "SUCCESS: synchronized latest Excel/XML and recovered $recovered missing archive generation(s). Archive folder: $archiveFolder"
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    if (Test-Path (Join-Path $archiveFolder 'manifest.json.download')) {
        Remove-Item -LiteralPath (Join-Path $archiveFolder 'manifest.json.download') -Force -ErrorAction SilentlyContinue
    }
    exit 1
}

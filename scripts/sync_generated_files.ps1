param(
    [switch]$Install,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
$taskName = 'MuleSoftCustomerOrdersCloudSync'
$inputFolder = 'C:\Users\91938\Desktop\mulesoft file processing input data'
$logFolder = Join-Path $env:LOCALAPPDATA 'MuleSoftCustomerOrders'
$logFile = Join-Path $logFolder 'cloud-sync.log'
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

function Download-AndValidate([string]$Name, [string]$Kind) {
    $destination = Join-Path $inputFolder $Name
    $temp = $destination + '.download'
    Invoke-WebRequest -Uri "$baseUrl/$Name" -OutFile $temp -UseBasicParsing -TimeoutSec 60
    if (-not (Test-Path $temp) -or (Get-Item $temp).Length -lt 20) {
        throw "Downloaded file is missing or too small: $Name"
    }
    if ($Kind -eq 'xlsx' -and -not (Test-Xlsx $temp)) {
        throw "Downloaded XLSX is not a valid ZIP-based workbook: $Name"
    }
    if ($Kind -eq 'xml' -and -not (Test-Xml $temp)) {
        throw "Downloaded XML does not have the expected CustomerOrders root: $Name"
    }
    Move-Item -LiteralPath $temp -Destination $destination -Force
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
    Write-Host "Automatic cloud-to-PC sync installed. Files are saved directly to: $inputFolder"
    Write-Host 'The task checks GitHub every 2 minutes. Only the latest Excel and XML files are kept in the destination.'
    exit 0
}

try {
    Download-AndValidate 'customers_orders.xlsx' 'xlsx'
    Download-AndValidate 'customers_orders.xml' 'xml'

    # Remove the previously-created archive directory only when it is empty.
    $oldArchive = Join-Path $inputFolder 'archive'
    if ((Test-Path $oldArchive) -and -not (Get-ChildItem -LiteralPath $oldArchive -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $oldArchive -Force
    }

    Write-Log "SUCCESS: synchronized customers_orders.xlsx and customers_orders.xml directly to $inputFolder"
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    foreach ($name in @('customers_orders.xlsx', 'customers_orders.xml')) {
        $temp = Join-Path $inputFolder ($name + '.download')
        if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
    }
    exit 1
}

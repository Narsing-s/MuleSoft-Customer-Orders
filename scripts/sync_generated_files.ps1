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
$files = @('customers_orders.xlsx', 'customers_orders.xml')

New-Item -ItemType Directory -Path $inputFolder -Force | Out-Null
New-Item -ItemType Directory -Path $logFolder -Force | Out-Null

function Write-Log([string]$Message) {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" |
        Out-File -FilePath $logFile -Append -Encoding utf8
}

if ($Install) {
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { throw 'Could not determine the installed sync script path.' }
    $taskCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $scriptPath + '" -Run'
    & schtasks.exe /Create /SC MINUTE /MO 2 /TN $taskName /TR $taskCommand /F
    if ($LASTEXITCODE -ne 0) { throw 'Could not register the two-minute Windows scheduled task.' }
    Write-Log "Installed scheduled sync. Destination: $inputFolder"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Run
    if ($LASTEXITCODE -ne 0) { throw 'Initial sync failed. See cloud-sync.log.' }
    Write-Host "Automatic cloud-to-PC sync installed. Files are saved to: $inputFolder"
    Write-Host 'The task checks GitHub every 2 minutes.'
    exit 0
}

if (-not $Run) { $Run = $true }

try {
    $tempPaths = @{}
    foreach ($name in $files) {
        $temp = Join-Path $inputFolder ($name + '.download')
        $uri = "$baseUrl/$name"
        Invoke-WebRequest -Uri $uri -OutFile $temp -UseBasicParsing -TimeoutSec 45
        if (-not (Test-Path $temp) -or (Get-Item $temp).Length -lt 20) {
            throw "Downloaded file is missing or too small: $name"
        }
        $tempPaths[$name] = $temp
    }

    # Validate both downloads before replacing either destination file.
    $xmlPath = $tempPaths['customers_orders.xml']
    [xml]$xmlCheck = Get-Content -LiteralPath $xmlPath -Raw
    if ($xmlCheck.DocumentElement.LocalName -ne 'CustomerOrders') {
        throw 'The downloaded XML does not have the expected CustomerOrders root.'
    }
    $xlsxPath = $tempPaths['customers_orders.xlsx']
    $stream = [System.IO.File]::OpenRead($xlsxPath)
    try {
        $signature = New-Object byte[] 2
        [void]$stream.Read($signature, 0, 2)
        if ($signature[0] -ne 0x50 -or $signature[1] -ne 0x4B) {
            throw 'The downloaded XLSX is not a valid ZIP-based Excel workbook.'
        }
    } finally {
        $stream.Dispose()
    }

    foreach ($name in $files) {
        Move-Item -LiteralPath $tempPaths[$name] -Destination (Join-Path $inputFolder $name) -Force
    }
    Write-Log "SUCCESS: synchronized customers_orders.xlsx and customers_orders.xml to $inputFolder"
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    foreach ($name in $files) {
        $temp = Join-Path $inputFolder ($name + '.download')
        if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
    }
    exit 1
}

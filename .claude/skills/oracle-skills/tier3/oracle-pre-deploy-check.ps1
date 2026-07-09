<#
.SYNOPSIS
    Run all pre-deployment validation checks as a single pass/fail gate
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$TargetEnvironment,
    [Parameter(Mandatory=$false)]
    [ValidateSet('strict', 'basic')]
    [string]$ValidationMode = 'strict',
    [Parameter(Mandatory=$false)]
    [ValidateSet('combined', 'json-only', 'markdown-only')]
    [string]$ReportFormat = 'combined'
)

# Environment restriction: reject local
if ($TargetEnvironment -eq 'local') {
    Write-Output 'Pre-deployment checks are for staging/production only. Use local for development.'
    exit 1
}

$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath 'shared'
Import-Module (Join-Path $sharedPath 'OracleConnection.psm1') -Force
Import-Module (Join-Path $sharedPath 'SchemaInspector.psm1') -Force
Import-Module (Join-Path $sharedPath 'OutputFormatter.psm1') -Force

function Invoke-ConnectivityCheck {
    param([Parameter(Mandatory=$true)][string]$Environment)
    try {
        $isConnected = Test-OracleConnection -Environment $Environment
        if ($isConnected) {
            return @{ CheckName = 'Connectivity'; Status = 'Pass'; Message = "Connected to $Environment database successfully" }
        } else {
            return @{ CheckName = 'Connectivity'; Status = 'Fail'; Message = "Failed to connect to $Environment database" }
        }
    }
    catch {
        Write-Warning ('Connectivity check error: ' + $_.ToString())
        return @{ CheckName = 'Connectivity'; Status = 'Fail'; Message = 'Connectivity check failed' }
    }
}

function Aggregate-ValidationResults {
    param([Parameter(Mandatory=$true)][object[]]$CheckResults, [Parameter(Mandatory=$true)][string]$TargetEnvironment, [Parameter(Mandatory=$true)][string]$ValidationMode)
    $passCount = ($checkResults | Where-Object { $_.Status -eq 'Pass' } | Measure-Object).Count
    $failCount = ($checkResults | Where-Object { $_.Status -eq 'Fail' } | Measure-Object).Count
    $status = if ($failCount -eq 0) { 'DEPLOYMENT_READY' } else { 'DEPLOYMENT_BLOCKED' }
    return @{
        Status = $status
        TargetEnvironment = $TargetEnvironment
        ValidationMode = $ValidationMode
        Timestamp = ([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ssZ')
        Checks = $checkResults
        Summary = @{ Total = $checkResults.Count; Passed = $passCount; Failed = $failCount }
    }
}

function Format-ValidationReport {
    param([Parameter(Mandatory=$true)][hashtable]$Report, [Parameter(Mandatory=$true)][string]$ReportFormat)
    $output = @()
    if ($ReportFormat -ne 'markdown-only') {
        try {
            $jsonStr = ConvertTo-Json $Report -Depth 3
            $jsonBlock = '```json' + [Environment]::NewLine + $jsonStr + [Environment]::NewLine + '```'
            $output += $jsonBlock
        }
        catch {
            Write-Warning ('Failed to convert report to JSON: ' + $_.ToString())
        }
    }
    if ($ReportFormat -ne 'json-only') {
        $mdLines = @('# Pre-Deployment Validation Report', '', "Environment: $($Report.TargetEnvironment)", "Status: $($Report.Status)")
        $mdBlock = $mdLines -join [Environment]::NewLine
        $output += $mdBlock
    }
    return $output -join [Environment]::NewLine
}

try {
    $checksToRun = @(Invoke-ConnectivityCheck -Environment $TargetEnvironment)
    $report = Aggregate-ValidationResults -CheckResults $checksToRun -TargetEnvironment $TargetEnvironment -ValidationMode $ValidationMode
    $formattedOutput = Format-ValidationReport -Report $report -ReportFormat $ReportFormat
    Write-Output $formattedOutput
    $exitCode = if ($report.Status -eq 'DEPLOYMENT_READY') { 0 } else { 1 }
    exit $exitCode
}
catch {
    Write-Warning ('Pre-deployment check failed: ' + $_.ToString())
    exit 1
}

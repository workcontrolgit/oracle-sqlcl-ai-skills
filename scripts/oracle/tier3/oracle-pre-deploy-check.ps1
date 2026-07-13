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

function Invoke-SchemaDriftCheck {
    param([Parameter(Mandatory=$true)][string]$Environment)
    try {
        # Query database for manual schema changes outside of migrations
        $config = Get-EnvironmentConfig -Environment $Environment
        $query = "SELECT COUNT(*) as drift_count FROM all_tables WHERE owner NOT IN ('SYS', 'SYSTEM', 'SYSAUX') AND created > (SELECT MAX(applied_at) FROM schema_migrations)"
        $result = Invoke-OracleQuery -Query $query -TargetEnvironment $Environment

        if ($result -and $result.drift_count -gt 0) {
            return @{ CheckName = 'SchemaDrift'; Status = 'Fail'; Message = "Schema drift detected: $($result.drift_count) manual changes found" }
        } else {
            return @{ CheckName = 'SchemaDrift'; Status = 'Pass'; Message = "No schema drift detected" }
        }
    }
    catch {
        Write-Warning ('Schema drift check error: ' + $_.ToString())
        return @{ CheckName = 'SchemaDrift'; Status = 'Fail'; Message = 'Schema drift check failed' }
    }
}

function Invoke-MigrationStatusCheck {
    param([Parameter(Mandatory=$true)][string]$Environment)
    try {
        # Verify all expected migrations have been applied
        $query = "SELECT COUNT(*) as total FROM schema_migrations WHERE status NOT IN ('SUCCESS', 'APPLIED', 'COMPLETED')"
        $result = Invoke-OracleQuery -Query $query -TargetEnvironment $Environment

        if ($result -and $result.total -eq 0) {
            return @{ CheckName = 'MigrationStatus'; Status = 'Pass'; Message = "All migrations have been applied successfully" }
        } else {
            $pending = if ($result) { $result.total } else { 0 }
            return @{ CheckName = 'MigrationStatus'; Status = 'Fail'; Message = "Found $pending unapplied or failed migrations" }
        }
    }
    catch {
        Write-Warning ('Migration status check error: ' + $_.ToString())
        return @{ CheckName = 'MigrationStatus'; Status = 'Fail'; Message = 'Migration status check failed' }
    }
}

function Invoke-UserPermissionsCheck {
    param([Parameter(Mandatory=$true)][string]$Environment)
    try {
        # Verify user has required deployment privileges
        $query = "SELECT COUNT(*) as priv_count FROM session_privs WHERE privilege IN ('CREATE TABLE', 'ALTER TABLE', 'DROP TABLE', 'CREATE PROCEDURE', 'EXECUTE')"
        $result = Invoke-OracleQuery -Query $query -TargetEnvironment $Environment

        if ($result -and $result.priv_count -ge 5) {
            return @{ CheckName = 'UserPermissions'; Status = 'Pass'; Message = "User has required deployment privileges" }
        } else {
            $privs = if ($result) { $result.priv_count } else { 0 }
            return @{ CheckName = 'UserPermissions'; Status = 'Fail'; Message = "User has insufficient privileges (found $privs of 5 required)" }
        }
    }
    catch {
        Write-Warning ('User permissions check error: ' + $_.ToString())
        return @{ CheckName = 'UserPermissions'; Status = 'Fail'; Message = 'User permissions check failed' }
    }
}

function Aggregate-ValidationResults {
    param([Parameter(Mandatory=$true)][object[]]$CheckResults, [Parameter(Mandatory=$true)][string]$TargetEnvironment, [Parameter(Mandatory=$true)][string]$ValidationMode)

    # Handle null or empty results
    if ($null -eq $CheckResults -or $CheckResults.Count -eq 0) {
        return @{
            Status = 'ERROR'
            TargetEnvironment = $TargetEnvironment
            ValidationMode = $ValidationMode
            Timestamp = ([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ssZ')
            Checks = @()
            Summary = @{ Total = 0; Passed = 0; Failed = 0; Error = 1 }
        }
    }

    $passCount = ($checkResults | Where-Object { $_.Status -eq 'Pass' } | Measure-Object).Count
    $failCount = ($checkResults | Where-Object { $_.Status -eq 'Fail' } | Measure-Object).Count
    $errorCount = ($checkResults | Where-Object { $null -eq $_ } | Measure-Object).Count

    # Determine status
    $status = if ($errorCount -gt 0) { 'ERROR' }
              elseif ($failCount -eq 0) { 'DEPLOYMENT_READY' }
              else { 'DEPLOYMENT_BLOCKED' }

    return @{
        Status = $status
        TargetEnvironment = $TargetEnvironment
        ValidationMode = $ValidationMode
        Timestamp = ([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ssZ')
        Checks = $checkResults
        Summary = @{ Total = $checkResults.Count; Passed = $passCount; Failed = $failCount; Error = $errorCount }
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
    # Determine which checks to run based on ValidationMode
    if ($ValidationMode -eq 'strict') {
        $checksToRun = @(
            Invoke-ConnectivityCheck -Environment $TargetEnvironment,
            Invoke-SchemaDriftCheck -Environment $TargetEnvironment,
            Invoke-MigrationStatusCheck -Environment $TargetEnvironment,
            Invoke-UserPermissionsCheck -Environment $TargetEnvironment
        )
    } else {
        # basic mode: only connectivity check
        $checksToRun = @(
            Invoke-ConnectivityCheck -Environment $TargetEnvironment
        )
    }

    # Filter out null results (errors)
    $checksToRun = @($checksToRun | Where-Object { $null -ne $_ })

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

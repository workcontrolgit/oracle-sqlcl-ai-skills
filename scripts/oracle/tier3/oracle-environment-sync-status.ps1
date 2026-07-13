<#
.SYNOPSIS
    Check sync status across Oracle environments by comparing migration versions
.DESCRIPTION
    Queries the migration table in each configured environment (local, staging, production)
    and compares the latest applied migration version. Reports IN_SYNC, OUT_OF_SYNC, or ERROR.
.PARAMETER OutputFormat
    Full (default): JSON block + markdown table. Summary: JSON block only.
.PARAMETER MigrationsTable
    Name of the migrations tracking table. Default: SCHEMA_MIGRATIONS
#>
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('Full', 'Summary')]
    [string]$OutputFormat = 'Full',

    [Parameter(Mandatory=$false)]
    [ValidatePattern('(?-i)^[A-Z0-9_]{1,30}$')]
    [string]$MigrationsTable = 'SCHEMA_MIGRATIONS'
)

$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath 'shared'
Import-Module (Join-Path $sharedPath 'OracleConnection.psm1') -Force
Import-Module (Join-Path $sharedPath 'SchemaInspector.psm1') -Force
Import-Module (Join-Path $sharedPath 'OutputFormatter.psm1') -Force

# ---------------------------------------------------------------------------
# Get the latest applied migration version from a single environment
# ---------------------------------------------------------------------------
function Get-EnvironmentVersion {
    param(
        [Parameter(Mandatory=$true)][string]$Environment,
        [Parameter(Mandatory=$true)][string]$MigrationsTable
    )
    try {
        $isConnected = Test-OracleConnection -Environment $Environment
        if (-not $isConnected) {
            return @{ Version = $null; Available = $false }
        }

        $tableExists = Test-TableExists -TableName $MigrationsTable -TargetEnvironment $Environment
        if (-not $tableExists) {
            return @{ Version = $null; Available = $false }
        }

        $query = "SELECT MAX(migration_id) as latest_version FROM $MigrationsTable WHERE status IN ('SUCCESS', 'APPLIED', 'COMPLETED')"
        $result = Invoke-OracleQuery -Query $query -TargetEnvironment $Environment
        if ($null -eq $result) {
            return @{ Version = $null; Available = $false }
        }
        return @{ Version = $result.latest_version; Available = $true }
    }
    catch {
        Write-Warning ('Failed to query version for environment ' + $Environment + ': ' + $_.ToString())
        return @{ Version = $null; Available = $false }
    }
}

# ---------------------------------------------------------------------------
# Compare versions across environments and classify sync state
# ---------------------------------------------------------------------------
function Compare-EnvironmentVersions {
    param(
        [Parameter(Mandatory=$true)][hashtable]$EnvironmentVersions
    )

    # Collect available versions
    $availableVersions = @()
    foreach ($env in $EnvironmentVersions.Keys) {
        $info = $EnvironmentVersions[$env]
        if ($info.Available -eq $true -and $null -ne $info.Version) {
            $availableVersions += $info.Version
        }
    }

    # Determine overall status
    $overallStatus = "ERROR"
    if ($availableVersions.Count -gt 0) {
        $distinctVersions = @($availableVersions | Select-Object -Unique)
        if ($distinctVersions.Count -eq 1) {
            $overallStatus = "IN_SYNC"
        } else {
            $overallStatus = "OUT_OF_SYNC"
        }
    }

    # Find max and min versions among available environments
    $maxVersion = $null
    $minVersion = $null
    if ($availableVersions.Count -gt 0) {
        $sorted = @($availableVersions | Sort-Object)
        $minVersion = $sorted[0]
        $maxVersion = $sorted[$sorted.Count - 1]
    }

    # Classify each environment
    $envResults = @{}
    $inSyncCount = 0
    $outOfSyncCount = 0
    $unavailableCount = 0

    foreach ($env in $EnvironmentVersions.Keys) {
        $info = $EnvironmentVersions[$env]
        if ($info.Available -ne $true -or $null -eq $info.Version) {
            $envResults[$env] = @{
                Version   = $null
                Status    = "Unavailable"
                Available = $false
            }
            $unavailableCount++
        } else {
            $ver = $info.Version
            $envStatus = "InSync"
            if ($overallStatus -eq "OUT_OF_SYNC") {
                if ($ver -eq $maxVersion -and $ver -ne $minVersion) {
                    $envStatus = "Ahead"
                } elseif ($ver -eq $minVersion -and $ver -ne $maxVersion) {
                    $envStatus = "Behind"
                } else {
                    $envStatus = "InSync"
                }
            }
            $envResults[$env] = @{
                Version   = $ver
                Status    = $envStatus
                Available = $true
            }
            if ($envStatus -eq "InSync") {
                $inSyncCount++
            } else {
                $outOfSyncCount++
            }
        }
    }

    return @{
        Status              = $overallStatus
        EnvironmentVersions = $envResults
        InSyncCount         = $inSyncCount
        OutOfSyncCount      = $outOfSyncCount
        UnavailableCount    = $unavailableCount
    }
}

# ---------------------------------------------------------------------------
# Main execution
# ---------------------------------------------------------------------------

# Query each environment
$environments = @('local', 'staging', 'production')
$envVersions = @{}
foreach ($env in $environments) {
    $envVersions[$env] = Get-EnvironmentVersion -Environment $env -MigrationsTable $MigrationsTable
}

# Compare
$comparison = Compare-EnvironmentVersions -EnvironmentVersions $envVersions
$comparison.Timestamp = ([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ssZ')
$comparison.MigrationsTable = $MigrationsTable

# Build JSON output block
$jsonBlock = '```json' + [Environment]::NewLine + (ConvertTo-DiagnosticJson -Result $comparison) + [Environment]::NewLine + '```'

if ($OutputFormat -eq 'Summary') {
    # Summary: JSON block only
    Write-Output $jsonBlock
} else {
    # Full: JSON block + markdown table per environment
    $tableRows = @()
    foreach ($env in $environments) {
        $info = $comparison.EnvironmentVersions[$env]
        if ($null -ne $info) {
            $tableRows += [PSCustomObject]@{
                Environment = $env
                Version     = if ($null -eq $info.Version) { 'N/A' } else { [string]$info.Version }
                Status      = $info.Status
                Available   = $info.Available.ToString()
            }
        }
    }
    $markdownTable = ConvertTo-MarkdownTable -Data $tableRows -Properties @('Environment', 'Version', 'Status', 'Available')
    $markdownBlock = '```markdown' + [Environment]::NewLine + $markdownTable + [Environment]::NewLine + '```'

    Write-Output $jsonBlock
    Write-Output ""
    Write-Output $markdownBlock
}

# Exit codes: 0 = IN_SYNC, 1 = OUT_OF_SYNC or ERROR
if ($comparison.Status -eq 'IN_SYNC') { exit 0 } else { exit 1 }

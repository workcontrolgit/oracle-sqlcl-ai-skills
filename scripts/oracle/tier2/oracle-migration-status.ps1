<#
.SYNOPSIS
    Query and display Oracle schema migration status
.DESCRIPTION
    Queries the SCHEMA_MIGRATIONS table (or DBA_REGISTRY) to show:
    - Current schema version
    - Total applied migrations
    - Total failed migrations (if any)
    - Last applied migration date
    - List of pending migrations (if any)
.PARAMETER Environment
    Target environment: local, staging, or production
.PARAMETER MigrationsTable
    Name of migrations table. Default: SCHEMA_MIGRATIONS
.EXAMPLE
    & oracle-migration-status.ps1 -Environment local
.EXAMPLE
    & oracle-migration-status.ps1 -Environment production -MigrationsTable CUSTOM_MIGRATIONS
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("local", "staging", "production")]
    [string]$Environment,

    [Parameter(Mandatory=$false)]
    [string]$MigrationsTable = "SCHEMA_MIGRATIONS"
)

# Import shared modules
$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared"
Import-Module (Join-Path $sharedPath "OracleConnection.psm1") -Force
Import-Module (Join-Path $sharedPath "OutputFormatter.psm1") -Force
Import-Module (Join-Path $sharedPath "SchemaInspector.psm1") -Force

function Get-MigrationStatus {
    <#
    .SYNOPSIS
        Query migrations table and return migration records
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment,

        [Parameter(Mandatory=$true)]
        [string]$MigrationsTable
    )

    try {
        # Validate table name
        if ($MigrationsTable -notmatch '^[A-Z0-9_]{1,30}$') {
            throw "Invalid migrations table name: must be 1-30 alphanumeric characters and underscore only"
        }

        $tableNameUpper = $MigrationsTable.ToUpper()

        # Check if table exists
        $tableExists = Test-TableExists -Environment $Environment -TableName $tableNameUpper
        if (-not $tableExists) {
            Write-Warning "Migrations table '$tableNameUpper' not found in schema"
            return $null
        }

        # Query migrations table
        $query = @"
SELECT
    migration_name as Name,
    migration_status as Status,
    applied_at as AppliedDate
FROM $tableNameUpper
ORDER BY applied_at DESC
"@

        $result = Invoke-OracleQuery -Environment $Environment -Query $query -OutputFormat "CSV"

        if ($null -eq $result) {
            Write-Warning "No migration records found or query failed"
            return $null
        }

        # Filter out header row if present
        return $result | Where-Object { $_.Name -ne "Name" -and $null -ne $_ }
    }
    catch {
        Write-Error "Failed to get migration status: $_"
        return $null
    }
}

function Get-CurrentVersion {
    <#
    .SYNOPSIS
        Find the latest successful migration version
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$Migrations
    )

    if ($null -eq $Migrations -or $Migrations.Count -eq 0) {
        return $null
    }

    # Find the latest migration with status = SUCCESS (or similar)
    $successful = $Migrations | Where-Object {
        $_.Status -match "SUCCESS|APPLIED|COMPLETED" -or $_.Status -eq "1"
    } | Select-Object -First 1

    if ($null -ne $successful) {
        return $successful.Name
    }

    return $null
}

function Get-FailedMigrations {
    <#
    .SYNOPSIS
        Get count and list of failed migrations
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$Migrations
    )

    if ($null -eq $Migrations) {
        return @{
            Count = 0
            List = @()
        }
    }

    $failed = $Migrations | Where-Object {
        $_.Status -match "FAIL|ERROR|FAILED" -or $_.Status -eq "0"
    }

    return @{
        Count = ($failed | Measure-Object).Count
        List = @($failed | Select-Object -ExpandProperty Name)
    }
}

function Get-PendingMigrations {
    <#
    .SYNOPSIS
        Get count and list of pending/unapplied migrations
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$Migrations
    )

    if ($null -eq $Migrations) {
        return @{
            Count = 0
            List = @()
        }
    }

    $pending = $Migrations | Where-Object {
        $_.Status -match "PENDING|UNAPPLIED|WAITING" -or $null -eq $_.AppliedDate
    }

    return @{
        Count = ($pending | Measure-Object).Count
        List = @($pending | Select-Object -ExpandProperty Name)
    }
}

try {
    # Query migrations
    $migrations = Get-MigrationStatus -Environment $Environment -MigrationsTable $MigrationsTable

    if ($null -eq $migrations) {
        $result = @{
            Status = "WARNING"
            Message = "No migrations table found or query failed"
            CurrentVersion = "N/A"
            TotalMigrations = 0
            FailedMigrations = 0
            LastAppliedDate = "N/A"
        }
        
        Write-Output (Format-FailureOutput -Result $result -Message "Migration status check completed with warnings")
        exit 1
    }

    # Normalize migrations to array
    if ($migrations -isnot [object[]]) {
        $migrations = @($migrations)
    }

    # Calculate statistics
    $currentVersion = Get-CurrentVersion -Migrations $migrations
    $failedMigrations = Get-FailedMigrations -Migrations $migrations
    $pendingMigrations = Get-PendingMigrations -Migrations $migrations

    # Get last applied date
    $lastApplied = $migrations |
        Where-Object { $_.AppliedDate -and $_.Status -match "SUCCESS|APPLIED|COMPLETED" } |
        Sort-Object AppliedDate -Descending |
        Select-Object -First 1

    $lastAppliedDate = if ($null -ne $lastApplied -and $lastApplied.AppliedDate) {
        $lastApplied.AppliedDate
    } else {
        "N/A"
    }

    # Prepare result
    $status = if ($failedMigrations.Count -gt 0) { "FAIL" } else { "PASS" }
    $message = if ($failedMigrations.Count -gt 0) {
        "Migration status check completed with $($failedMigrations.Count) failed migration(s)"
    } else {
        "All migrations applied successfully"
    }

    $result = @{
        Status = $status
        Message = $message
        CurrentVersion = if ($currentVersion) { $currentVersion } else { "N/A" }
        TotalMigrations = $migrations.Count
        AppliedMigrations = ($migrations | Where-Object { $_.Status -match "SUCCESS|APPLIED|COMPLETED" } | Measure-Object).Count
        FailedMigrations = $failedMigrations.Count
        PendingMigrations = $pendingMigrations.Count
        LastAppliedDate = $lastAppliedDate
    }

    # Add detailed lists if needed
    if ($failedMigrations.Count -gt 0) {
        $result["FailedMigrationsList"] = $failedMigrations.List
    }

    if ($pendingMigrations.Count -gt 0) {
        $result["PendingMigrationsList"] = $pendingMigrations.List
    }

    # Format and output
    if ($status -eq "PASS") {
        Write-Output (Format-SuccessOutput -Result $result -Message $message)
        exit 0
    } else {
        Write-Output (Format-FailureOutput -Result $result -Message $message)
        exit 1
    }
}
catch {
    $result = @{
        Status = "ERROR"
        Message = "Exception occurred during migration status check"
        Error = $_.Exception.Message
    }

    Write-Output (Format-FailureOutput -Result $result -Message "Migration status check failed with error: $_")
    exit 1
}

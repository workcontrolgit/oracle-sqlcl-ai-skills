<#
.SYNOPSIS
    Validate that all expected migrations have been applied in target environment
.DESCRIPTION
    Queries the SCHEMA_MIGRATIONS table (or custom migrations table) and validates
    that all expected migrations have been applied. Provides pipeline-ready JSON output
    plus human-readable markdown checklist. Exit code 0 for valid, 1 for invalid/error.
.PARAMETER Environment
    Target environment: local, staging, or production (mandatory)
.PARAMETER ExpectedMigrations
    Array or CSV string of expected migration names (mandatory)
    Examples: @("0001_init_schema", "0002_add_users"), or "0001_init,0002_add_users"
.PARAMETER MigrationsTable
    Name of migrations tracking table. Default: SCHEMA_MIGRATIONS
.EXAMPLE
    & oracle-migration-validate.ps1 -Environment local -ExpectedMigrations @("0001_init", "0002_users")
.EXAMPLE
    & oracle-migration-validate.ps1 -Environment production -ExpectedMigrations "0001_init,0002_users"
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("local", "staging", "production")]
    [string]$Environment,

    [Parameter(Mandatory=$true)]
    [object]$ExpectedMigrations,

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^[A-Z0-9_]{1,30}$')]
    [string]$MigrationsTable = "SCHEMA_MIGRATIONS"
)

# Import shared modules
$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared"
Import-Module (Join-Path $sharedPath "OracleConnection.psm1") -Force
Import-Module (Join-Path $sharedPath "SchemaInspector.psm1") -Force
Import-Module (Join-Path $sharedPath "OutputFormatter.psm1") -Force


function Parse-MigrationInput {
    <#
    .SYNOPSIS
        Parse expected migrations from array or CSV string
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object]$Input
    )

    try {
        # If already an array, return as-is
        if ($Input -is [object[]]) {
            return @($Input)
        }

        # If string, try to parse as CSV
        if ($Input -is [string]) {
            # Split by comma and trim whitespace
            $items = @($Input -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrEmpty($_) })
            return $items
        }

        # Single item (string or other), wrap in array
        return @($Input)
    }
    catch {
        Write-Error "Failed to parse migration input: $_"
        return @()
    }
}


function Get-AppliedMigrations {
    <#
    .SYNOPSIS
        Query migrations table and return applied migration names
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
            Write-Error "Migrations table '$tableNameUpper' not found in schema"
            return $null
        }

        # Query migrations table for applied migrations
        # Flexible query to handle different schema variations
        $query = @"
SELECT DISTINCT
    migration_name as Name,
    applied_at as AppliedAt
FROM $tableNameUpper
WHERE migration_name IS NOT NULL
ORDER BY applied_at DESC
"@

        $result = Invoke-OracleQuery -Environment $Environment -Query $query -OutputFormat "CSV"

        if ($null -eq $result) {
            return @()
        }

        # Normalize to array and filter out header row
        $migrations = @($result | Where-Object { $_.Name -ne "Name" -and -not [string]::IsNullOrEmpty($_.Name) })
        return $migrations
    }
    catch {
        Write-Error "Failed to get applied migrations: $_"
        return $null
    }
}


function Compare-MigrationSets {
    <#
    .SYNOPSIS
        Compare expected migrations against applied migrations
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$ExpectedMigrations,

        [Parameter(Mandatory=$true)]
        [object[]]$AppliedMigrations
    )

    try {
        $result = @{
            Applied = @()
            Missing = @()
            Extra = @()
        }

        # Get applied migration names
        $appliedNames = if ($null -ne $AppliedMigrations -and $AppliedMigrations.Count -gt 0) {
            @($AppliedMigrations | ForEach-Object {
                if ($_ -is [hashtable]) { $_["Name"] }
                elseif ($_ -is [pscustomobject]) { $_.Name }
                else { $_ -as [string] }
            })
        } else {
            @()
        }

        # Check each expected migration
        foreach ($expected in $ExpectedMigrations) {
            $expectedName = $expected -as [string]

            # Try to find matching migration (prefix matching OK)
            $matched = $false
            foreach ($applied in $AppliedMigrations) {
                $appliedName = if ($applied -is [hashtable]) { $applied["Name"] } elseif ($applied -is [pscustomobject]) { $applied.Name } else { $applied -as [string] }

                # Match if exact or if applied starts with expected
                if ($appliedName -eq $expectedName -or $appliedName -like "$expectedName*") {
                    $appliedAt = if ($applied -is [hashtable]) { $applied["AppliedAt"] } elseif ($applied -is [pscustomobject]) { $applied.AppliedAt } else { $null }
                    $result.Applied += @{
                        Name = $expectedName
                        AppliedAt = $appliedAt
                    }
                    $matched = $true
                    break
                }
            }

            if (-not $matched) {
                $result.Missing += @{
                    Name = $expectedName
                }
            }
        }

        # Find extra migrations (in applied but not in expected)
        foreach ($applied in $AppliedMigrations) {
            $appliedName = if ($applied -is [hashtable]) { $applied["Name"] } elseif ($applied -is [pscustomobject]) { $applied.Name } else { $applied -as [string] }

            $found = $false
            foreach ($expected in $ExpectedMigrations) {
                $expectedName = $expected -as [string]
                if ($appliedName -eq $expectedName -or $appliedName -like "$expectedName*") {
                    $found = $true
                    break
                }
            }

            if (-not $found) {
                $result.Extra += @{
                    Name = $appliedName
                }
            }
        }

        return $result
    }
    catch {
        Write-Error "Failed to compare migration sets: $_"
        return $null
    }
}


function Format-MigrationMarkdownTable {
    <#
    .SYNOPSIS
        Format migration validation results as markdown table
    #>
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$AppliedMigrations,

        [Parameter(Mandatory=$true)]
        [object[]]$MissingMigrations,

        [Parameter(Mandatory=$true)]
        [object[]]$ExtraMigrations
    )

    try {
        $lines = @()

        # Combine all migrations for table display
        $allMigrations = @()

        # Add applied migrations
        foreach ($migration in $AppliedMigrations) {
            $name = if ($migration -is [hashtable]) { $migration["Name"] } else { $migration.Name }
            $appliedAt = if ($migration -is [hashtable]) { $migration["AppliedAt"] } else { $migration.AppliedAt }

            # Escape markdown special characters
            $nameEscaped = $name -replace '\\', '\\' -replace '\|', '\|'
            $dateEscaped = if ($appliedAt) { ($appliedAt -as [string]) -replace '\\', '\\' -replace '\|', '\|' } else { "-" }

            $allMigrations += @{
                Migration = $nameEscaped
                Status = "[OK] Applied"
                AppliedAt = $dateEscaped
            }
        }

        # Add missing migrations
        foreach ($migration in $MissingMigrations) {
            $name = if ($migration -is [hashtable]) { $migration["Name"] } else { $migration.Name }

            # Escape markdown special characters
            $nameEscaped = $name -replace '\\', '\\' -replace '\|', '\|'

            $allMigrations += @{
                Migration = $nameEscaped
                Status = "[!!] Missing"
                AppliedAt = "-"
            }
        }

        # Add extra migrations (informational)
        foreach ($migration in $ExtraMigrations) {
            $name = if ($migration -is [hashtable]) { $migration["Name"] } else { $migration.Name }

            # Escape markdown special characters
            $nameEscaped = $name -replace '\\', '\\' -replace '\|', '\|'

            $allMigrations += @{
                Migration = $nameEscaped
                Status = "[*] Extra"
                AppliedAt = "-"
            }
        }

        # Generate markdown table
        if ($allMigrations.Count -gt 0) {
            return ConvertTo-MarkdownTable -Data $allMigrations -Properties @("Migration", "Status", "AppliedAt")
        }

        return ""
    }
    catch {
        Write-Error "Failed to format markdown table: $_"
        return ""
    }
}


try {
    # Parse expected migrations input
    $expectedMigrationsList = Parse-MigrationInput -Input $ExpectedMigrations

    if ($expectedMigrationsList.Count -eq 0) {
        throw "No expected migrations specified or parsing failed"
    }

    # Get applied migrations from database
    $appliedMigrationsList = Get-AppliedMigrations -Environment $Environment -MigrationsTable $MigrationsTable

    if ($null -eq $appliedMigrationsList) {
        # Table doesn't exist or query failed
        $result = @{
            Status = "ERROR"
            Environment = $Environment
            MigrationsTable = $MigrationsTable.ToUpper()
            Summary = @{
                Expected = $expectedMigrationsList.Count
                Applied = 0
                Missing = $expectedMigrationsList.Count
                Extra = 0
            }
            Migrations = @()
            Message = "Migrations table not found or query failed"
        }

        $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
        Write-Output $jsonOutput

        Write-Warning "Migration validation failed: Migrations table not found or query failed"
        exit 1
    }

    # Compare migration sets
    $comparison = Compare-MigrationSets -ExpectedMigrations $expectedMigrationsList -AppliedMigrations $appliedMigrationsList

    if ($null -eq $comparison) {
        throw "Comparison failed"
    }

    # Build migrations array for output
    $migrationsOutput = @()

    foreach ($migration in $comparison.Applied) {
        $migrationsOutput += @{
            Name = $migration.Name
            Status = "Applied"
            AppliedAt = if ($migration.AppliedAt) { $migration.AppliedAt } else { $null }
        }
    }

    foreach ($migration in $comparison.Missing) {
        $migrationsOutput += @{
            Name = $migration.Name
            Status = "Missing"
        }
    }

    foreach ($migration in $comparison.Extra) {
        $migrationsOutput += @{
            Name = $migration.Name
            Status = "Extra"
        }
    }

    # Determine overall status
    $isMissingMigrations = $comparison.Missing.Count -gt 0
    $validationStatus = if ($isMissingMigrations) { "INVALID" } else { "VALID" }

    # Build result
    $result = @{
        Status = $validationStatus
        Environment = $Environment
        MigrationsTable = $MigrationsTable.ToUpper()
        Summary = @{
            Expected = $expectedMigrationsList.Count
            Applied = $comparison.Applied.Count
            Missing = $comparison.Missing.Count
            Extra = $comparison.Extra.Count
        }
        Migrations = $migrationsOutput
    }

    # Generate markdown table
    $markdownTable = Format-MigrationMarkdownTable -AppliedMigrations $comparison.Applied -MissingMigrations $comparison.Missing -ExtraMigrations $comparison.Extra

    # Format output: JSON block
    $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"

    # Format output: markdown block
    $markdownLines = @()
    $markdownLines += "``````markdown"
    $markdownLines += "## Migration Validation Result"
    $markdownLines += ""
    $markdownLines += "- **Status**: $($result.Status)"
    $markdownLines += "- **Environment**: $($result.Environment)"
    $markdownLines += "- **Migrations Table**: $($result.MigrationsTable)"
    $markdownLines += ""
    $markdownLines += "## Summary"
    $markdownLines += ""
    $markdownLines += "- **Expected**: $($result.Summary.Expected)"
    $markdownLines += "- **Applied**: $($result.Summary.Applied)"
    $markdownLines += "- **Missing**: $($result.Summary.Missing)"
    $markdownLines += "- **Extra**: $($result.Summary.Extra)"
    $markdownLines += ""

    if ($result.Summary.Missing -eq 0 -and $result.Summary.Applied -eq $result.Summary.Expected) {
        $markdownLines += "**Result**: All $($result.Summary.Expected) migrations applied successfully!"
    } else {
        $markdownLines += "**Result**: $($result.Summary.Missing)/$($result.Summary.Expected) migrations missing"
    }

    $markdownLines += ""
    $markdownLines += "## Migrations"
    $markdownLines += ""
    $markdownLines += $markdownTable
    $markdownLines += "``````"

    $markdownOutput = $markdownLines -join "`n"

    # Output combined blocks
    Write-Output $jsonOutput
    Write-Output ""
    Write-Output $markdownOutput

    # Exit with appropriate code
    if ($validationStatus -eq "VALID") {
        exit 0
    } else {
        exit 1
    }
}
catch {
    $result = @{
        Status = "ERROR"
        Environment = $Environment
        MigrationsTable = $MigrationsTable.ToUpper()
        Summary = @{
            Expected = 0
            Applied = 0
            Missing = 0
            Extra = 0
        }
        Migrations = @()
        Message = $_.Exception.Message
    }

    # Output error as JSON
    $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
    Write-Output $jsonOutput

    Write-Error "Migration validation failed: $_"
    exit 1
}

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("local", "staging", "production")]
    [string]$Environment,

    [Parameter(Mandatory=$false)]
    [ValidatePattern('^[A-Z0-9_]{1,30}$')]
    [string]$MigrationsTable = "SCHEMA_MIGRATIONS"
)

$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared"
Import-Module (Join-Path $sharedPath "OracleConnection.psm1") -Force
Import-Module (Join-Path $sharedPath "OutputFormatter.psm1") -Force
Import-Module (Join-Path $sharedPath "SchemaInspector.psm1") -Force

function Get-CurrentSchemaSnapshot {
    param([Parameter(Mandatory=$true)][ValidateSet("local", "staging", "production")][string]$Environment)
    try {
        $schema = @{Tables = @(); Columns = @{}; Constraints = @{}}
        $tables = Get-TableList -Environment $Environment
        if ($null -eq $tables) { return $schema }
        if ($tables -isnot [object[]]) { $tables = @($tables) }
        foreach ($table in $tables) {
            $tableName = $table.Name
            if ([string]::IsNullOrEmpty($tableName)) { continue }
            $schema.Tables += $tableName
            $columns = Get-TableColumns -Environment $Environment -TableName $tableName
            if ($null -ne $columns) {
                if ($columns -isnot [object[]]) { $columns = @($columns) }
                $schema.Columns[$tableName] = $columns
            }
            $constraints = Get-TableConstraints -Environment $Environment -TableName $tableName
            if ($null -ne $constraints) {
                if ($constraints -isnot [object[]]) { $constraints = @($constraints) }
                $schema.Constraints[$tableName] = $constraints
            }
        }
        return $schema
    } catch {
        Write-Error "Failed to get schema snapshot: $_"
        return $null
    }
}

function Get-MigrationVersion {
    param([Parameter(Mandatory=$true)][ValidateSet("local", "staging", "production")][string]$Environment, [Parameter(Mandatory=$true)][string]$MigrationsTable)
    try {
        if ($MigrationsTable -notmatch '^[A-Z0-9_]{1,30}$') {
            throw "Invalid table name: must be 1-30 alphanumeric and underscore only"
        }
        $tableNameUpper = $MigrationsTable.ToUpper()
        $tableExists = Test-TableExists -Environment $Environment -TableName $tableNameUpper
        if (-not $tableExists) {
            Write-Warning "Migrations table not found"
            return $null
        }
        $query = @"
SELECT migration_name as Name, applied_at as AppliedDate
FROM $tableNameUpper
WHERE migration_status IN ('SUCCESS','APPLIED','COMPLETED','1')
ORDER BY applied_at DESC
FETCH FIRST 1 ROW ONLY
"@
        $result = Invoke-OracleQuery -Environment $Environment -Query $query -OutputFormat "CSV"
        if ($null -eq $result) { return $null }
        if ($result -isnot [object[]]) { $result = @($result) }
        $migration = $result | Where-Object { $_.Name -ne "Name" -and -not [string]::IsNullOrEmpty($_.Name) } | Select-Object -First 1
        return if ($null -ne $migration) { $migration.Name } else { $null }
    } catch {
        Write-Error "Failed to get migration version: $_"
        return $null
    }
}

function Get-ExpectedSchema {
    <#
    .SYNOPSIS
        Reconstruct expected schema state from migration records
    #>
    param([Parameter(Mandatory=$true)][ValidateSet("local", "staging", "production")][string]$Environment)
    try {
        # For Phase 2, use HR schema baseline as expected state
        # Future enhancement: make this migration-driven via metadata analysis
        $expected = @{
            Tables = @("EMPLOYEES","DEPARTMENTS","JOBS","LOCATIONS","COUNTRIES","REGIONS")
            Columns = @{
                EMPLOYEES = @("EMPLOYEE_ID","FIRST_NAME","LAST_NAME","EMAIL","PHONE_NUMBER","HIRE_DATE","JOB_ID","SALARY","COMMISSION_PCT","MANAGER_ID","DEPARTMENT_ID")
                DEPARTMENTS = @("DEPARTMENT_ID","DEPARTMENT_NAME","MANAGER_ID","LOCATION_ID")
                JOBS = @("JOB_ID","JOB_TITLE","MIN_SALARY","MAX_SALARY")
                LOCATIONS = @("LOCATION_ID","STREET_ADDRESS","POSTAL_CODE","CITY","STATE_PROVINCE","COUNTRY_ID")
                COUNTRIES = @("COUNTRY_ID","COUNTRY_NAME","REGION_ID")
                REGIONS = @("REGION_ID","REGION_NAME")
            }
            Constraints = @{
                EMPLOYEES = @("PK_EMPLOYEE_ID","FK_DEPARTMENT_ID","FK_JOB_ID","FK_MANAGER_ID")
                DEPARTMENTS = @("PK_DEPARTMENT_ID","FK_LOCATION_ID")
                JOBS = @("PK_JOB_ID")
                LOCATIONS = @("PK_LOCATION_ID","FK_COUNTRY_ID")
                COUNTRIES = @("PK_COUNTRY_ID","FK_REGION_ID")
                REGIONS = @("PK_REGION_ID")
            }
        }
        return $expected
    } catch {
        Write-Error "Failed to get expected schema: $_"
        return $null
    }
}

function Compare-SchemaForConflicts {
    param([Parameter(Mandatory=$true)][hashtable]$CurrentSchema, [Parameter(Mandatory=$true)][hashtable]$ExpectedSchema)
    try {
        $conflicts = @{
            Drift = @()
            Missing = @()
            Unexpected = @()
            Status = "PASS"
        }

        # Check for drift: tables in actual but not expected
        foreach ($table in $CurrentSchema.Tables) {
            if ($ExpectedSchema.Tables -notcontains $table) {
                $conflicts.Drift += @{
                    Type = "TABLE"
                    Name = $table
                    Status = "Extra in actual"
                }
                $conflicts.Status = "CONFLICTS_DETECTED"
            }
        }

        # Check for drift: columns in actual but not expected
        foreach ($tableName in $CurrentSchema.Columns.Keys) {
            if ($ExpectedSchema.Columns.ContainsKey($tableName)) {
                $currentCols = $CurrentSchema.Columns[$tableName] | ForEach-Object { $_.Name }
                $expectedCols = $ExpectedSchema.Columns[$tableName]
                foreach ($col in $currentCols) {
                    if ($expectedCols -notcontains $col) {
                        $conflicts.Drift += @{
                            Type = "COLUMN"
                            Table = $tableName
                            Name = $col
                            Status = "Extra in actual"
                        }
                        $conflicts.Status = "CONFLICTS_DETECTED"
                    }
                }
            }
        }

        # Check for drift: constraints in actual but not expected
        foreach ($tableName in $CurrentSchema.Constraints.Keys) {
            if ($ExpectedSchema.Constraints.ContainsKey($tableName)) {
                $currentConstraints = $CurrentSchema.Constraints[$tableName] | ForEach-Object { $_.Name }
                $expectedConstraints = $ExpectedSchema.Constraints[$tableName]
                foreach ($constraint in $currentConstraints) {
                    if ($expectedConstraints -notcontains $constraint) {
                        $conflicts.Drift += @{
                            Type = "CONSTRAINT"
                            Table = $tableName
                            Name = $constraint
                            Status = "Extra in actual"
                        }
                        $conflicts.Status = "CONFLICTS_DETECTED"
                    }
                }
            }
        }

        # Check for missing: tables in expected but not actual
        foreach ($table in $ExpectedSchema.Tables) {
            if ($CurrentSchema.Tables -notcontains $table) {
                $conflicts.Missing += @{
                    Type = "TABLE"
                    Name = $table
                    Status = "Missing from actual"
                }
                $conflicts.Status = "CONFLICTS_DETECTED"
            }
        }

        # Check for missing: columns in expected but not actual
        foreach ($tableName in $ExpectedSchema.Columns.Keys) {
            if ($CurrentSchema.Columns.ContainsKey($tableName)) {
                $expectedCols = $ExpectedSchema.Columns[$tableName]
                $currentCols = $CurrentSchema.Columns[$tableName] | ForEach-Object { $_.Name }
                foreach ($col in $expectedCols) {
                    if ($currentCols -notcontains $col) {
                        $conflicts.Missing += @{
                            Type = "COLUMN"
                            Table = $tableName
                            Name = $col
                            Status = "Missing from actual"
                        }
                        $conflicts.Status = "CONFLICTS_DETECTED"
                    }
                }
            } else {
                # Table doesn't exist, so all its columns are missing
                foreach ($col in $ExpectedSchema.Columns[$tableName]) {
                    $conflicts.Missing += @{
                        Type = "COLUMN"
                        Table = $tableName
                        Name = $col
                        Status = "Missing from actual (table missing)"
                    }
                    $conflicts.Status = "CONFLICTS_DETECTED"
                }
            }
        }

        # Check for missing: constraints in expected but not actual
        foreach ($tableName in $ExpectedSchema.Constraints.Keys) {
            if ($CurrentSchema.Constraints.ContainsKey($tableName)) {
                $expectedConstraints = $ExpectedSchema.Constraints[$tableName]
                $currentConstraints = $CurrentSchema.Constraints[$tableName] | ForEach-Object { $_.Name }
                foreach ($constraint in $expectedConstraints) {
                    if ($currentConstraints -notcontains $constraint) {
                        $conflicts.Missing += @{
                            Type = "CONSTRAINT"
                            Table = $tableName
                            Name = $constraint
                            Status = "Missing from actual"
                        }
                        $conflicts.Status = "CONFLICTS_DETECTED"
                    }
                }
            } else {
                # Table doesn't exist, so all its constraints are missing
                foreach ($constraint in $ExpectedSchema.Constraints[$tableName]) {
                    $conflicts.Missing += @{
                        Type = "CONSTRAINT"
                        Table = $tableName
                        Name = $constraint
                        Status = "Missing from actual (table missing)"
                    }
                    $conflicts.Status = "CONFLICTS_DETECTED"
                }
            }
        }

        return $conflicts
    } catch {
        Write-Error "Failed to compare schemas for conflicts: $_"
        return $null
    }
}

try {
    $currentSchema = Get-CurrentSchemaSnapshot -Environment $Environment
    if ($null -eq $currentSchema) {
        $result = @{Status = "ERROR"; Message = "Failed to retrieve schema"; Environment = $Environment; TablesAnalyzed = 0}
        Write-Output (Format-FailureOutput -Result $result -Message "Schema conflict detection failed")
        exit 1
    }

    $expectedSchema = Get-ExpectedSchema -Environment $Environment
    if ($null -eq $expectedSchema) {
        $result = @{Status = "ERROR"; Message = "Failed to retrieve expected schema"; Environment = $Environment}
        Write-Output (Format-FailureOutput -Result $result -Message "Schema conflict detection failed")
        exit 1
    }

    $migrationVersion = Get-MigrationVersion -Environment $Environment -MigrationsTable $MigrationsTable

    $conflicts = Compare-SchemaForConflicts -CurrentSchema $currentSchema -ExpectedSchema $expectedSchema
    if ($null -eq $conflicts) {
        $result = @{Status = "ERROR"; Message = "Failed to compare schemas"; Environment = $Environment}
        Write-Output (Format-FailureOutput -Result $result -Message "Schema conflict detection failed")
        exit 1
    }

    # Build result
    $result = @{
        Title = "Schema Conflict Detection"
        Status = $conflicts.Status
        Environment = $Environment
        CurrentVersion = if ($migrationVersion) { $migrationVersion } else { "N/A" }
        TablesAnalyzed = $currentSchema.Tables.Count
        DriftDetected = $conflicts.Drift.Count
        MissingObjects = $conflicts.Missing.Count
        UnexpectedObjects = 0
    }

    # Add Details section only if conflicts exist
    if ($conflicts.Drift.Count -gt 0 -or $conflicts.Missing.Count -gt 0) {
        $details = @{}
        if ($conflicts.Drift.Count -gt 0) {
            $details["Drift"] = $conflicts.Drift
        }
        if ($conflicts.Missing.Count -gt 0) {
            $details["Missing"] = $conflicts.Missing
        }
        $result["Details"] = $details
    }

    $message = if ($conflicts.Status -eq "PASS") {
        "No schema conflicts detected"
    } else {
        "Schema conflicts detected: $($conflicts.Drift.Count) drift object(s), $($conflicts.Missing.Count) missing object(s)"
    }

    # Format output directly (don't use Format-SuccessOutput/FailureOutput as they override Status)
    $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
    $markdownOutput = "``````markdown`n"
    $markdownOutput += "- **Title**: $($result.Title)`n"
    $markdownOutput += "- **Status**: $($result.Status)`n"
    $markdownOutput += "- **Environment**: $($result.Environment)`n"
    $markdownOutput += "- **CurrentVersion**: $($result.CurrentVersion)`n"
    $markdownOutput += "- **TablesAnalyzed**: $($result.TablesAnalyzed)`n"
    $markdownOutput += "- **DriftDetected**: $($result.DriftDetected)`n"
    $markdownOutput += "- **MissingObjects**: $($result.MissingObjects)`n"
    $markdownOutput += "- **UnexpectedObjects**: $($result.UnexpectedObjects)`n"
    $markdownOutput += "`n**Message**: $message`n"
    if ($result.ContainsKey("Details")) {
        if ($result.Details.ContainsKey("Drift") -and $result.Details["Drift"].Count -gt 0) {
            $markdownOutput += "`n**Drift Objects**:`n"
            $markdownOutput += (ConvertTo-MarkdownTable -Data $result.Details["Drift"])
        }
        if ($result.Details.ContainsKey("Missing") -and $result.Details["Missing"].Count -gt 0) {
            $markdownOutput += "`n**Missing Objects**:`n"
            $markdownOutput += (ConvertTo-MarkdownTable -Data $result.Details["Missing"])
        }
    }
    $markdownOutput += "`n``````"

    Write-Output ($jsonOutput + "`n`n" + $markdownOutput)

    if ($conflicts.Status -eq "PASS") {
        exit 0
    } else {
        exit 1
    }
}
catch {
    $result = @{Status = "ERROR"; Message = "Exception occurred"; Error = $_.Exception.Message; Environment = $Environment}
    Write-Output (Format-FailureOutput -Result $result -Message "Schema conflict detection failed: $_")
    exit 1
}

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("local", "staging", "production")]
    [string]$Environment,

    [Parameter(Mandatory=$false)]
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

function Compare-Schemas {
    param([Parameter(Mandatory=$true)][hashtable]$CurrentSchema)
    try {
        $diff = @{MissingTables = @(); MissingColumns = @(); MissingConstraints = @(); UnexpectedTables = @(); Status = "PASS"}
        $expectedTables = @("EMPLOYEES","DEPARTMENTS","JOBS","LOCATIONS","COUNTRIES","REGIONS")
        $expectedColumns = @{
            EMPLOYEES = @("EMPLOYEE_ID","FIRST_NAME","LAST_NAME","EMAIL","PHONE_NUMBER","HIRE_DATE","JOB_ID","SALARY","COMMISSION_PCT","MANAGER_ID","DEPARTMENT_ID")
            DEPARTMENTS = @("DEPARTMENT_ID","DEPARTMENT_NAME","MANAGER_ID","LOCATION_ID")
            JOBS = @("JOB_ID","JOB_TITLE","MIN_SALARY","MAX_SALARY")
        }
        foreach ($expectedTable in $expectedTables) {
            if ($CurrentSchema.Tables -notcontains $expectedTable) {
                $diff.MissingTables += @{Table = $expectedTable}
                $diff.Status = "DIFFERENCES_FOUND"
            }
        }
        foreach ($tableName in $expectedColumns.Keys) {
            if ($CurrentSchema.Columns.ContainsKey($tableName)) {
                $currentCols = $CurrentSchema.Columns[$tableName] | ForEach-Object { $_.Name }
                foreach ($expectedCol in $expectedColumns[$tableName]) {
                    if ($currentCols -notcontains $expectedCol) {
                        $diff.MissingColumns += @{Table = $tableName; Column = $expectedCol; Type = "UNKNOWN"}
                        $diff.Status = "DIFFERENCES_FOUND"
                    }
                }
            }
        }
        foreach ($tableName in $expectedTables) {
            if ($CurrentSchema.Constraints.ContainsKey($tableName)) {
                $constraints = $CurrentSchema.Constraints[$tableName]
                $pkExists = $constraints | Where-Object { $_.Type -eq "P" }
                if ($null -eq $pkExists) {
                    if ($CurrentSchema.Tables -contains $tableName) {
                        $diff.MissingConstraints += @{Table = $tableName; Constraint = "PK_$tableName"; Type = "PRIMARY_KEY"}
                        $diff.Status = "DIFFERENCES_FOUND"
                    }
                }
            }
        }
        return $diff
    } catch {
        Write-Error "Failed to compare schemas: $_"
        return $null
    }
}

try {
    $currentSchema = Get-CurrentSchemaSnapshot -Environment $Environment
    if ($null -eq $currentSchema) {
        $result = @{Status = "ERROR"; Message = "Failed to retrieve schema"; Environment = $Environment; TablesAnalyzed = 0}
        Write-Output (Format-FailureOutput -Result $result -Message "Schema diff check failed")
        exit 1
    }
    $migrationVersion = Get-MigrationVersion -Environment $Environment -MigrationsTable $MigrationsTable
    $diff = Compare-Schemas -CurrentSchema $currentSchema
    if ($null -eq $diff) {
        $result = @{Status = "ERROR"; Message = "Failed to compare schemas"; Environment = $Environment}
        Write-Output (Format-FailureOutput -Result $result -Message "Schema diff check failed")
        exit 1
    }
    $result = @{
        Title = "Schema Migration Diff"
        Status = $diff.Status
        Environment = $Environment
        CurrentVersion = if ($migrationVersion) { $migrationVersion } else { "N/A" }
        TablesAnalyzed = $currentSchema.Tables.Count
        MissingTables = $diff.MissingTables.Count
        MissingColumns = $diff.MissingColumns.Count
        MissingConstraints = $diff.MissingConstraints.Count
        UnexpectedTables = $diff.UnexpectedTables.Count
    }
    if ($diff.MissingColumns.Count -gt 0) {
        $result["Details"] = @{MissingColumns = $diff.MissingColumns}
    }
    if ($diff.MissingConstraints.Count -gt 0) {
        if (-not $result.ContainsKey("Details")) { $result["Details"] = @{} }
        $result.Details["MissingConstraints"] = $diff.MissingConstraints
    }
    $message = if ($diff.Status -eq "PASS") {"Schema matches expected state"} else {"Schema differences found: $($diff.MissingTables.Count) missing tables, $($diff.MissingColumns.Count) missing columns, $($diff.MissingConstraints.Count) missing constraints"}
    if ($diff.Status -eq "PASS") {
        Write-Output (Format-SuccessOutput -Result $result -Message $message)
        exit 0
    } else {
        Write-Output (Format-FailureOutput -Result $result -Message $message)
        exit 1
    }
} catch {
    $result = @{Status = "ERROR"; Message = "Exception occurred"; Error = $_.Exception.Message; Environment = $Environment}
    Write-Output (Format-FailureOutput -Result $result -Message "Schema diff check failed: $_")
    exit 1
}

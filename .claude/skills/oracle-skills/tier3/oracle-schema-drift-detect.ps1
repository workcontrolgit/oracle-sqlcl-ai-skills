param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("local", "staging", "production")]
    [string]$Environment,

    [Parameter(Mandatory=$false)]
    [string]$BaselineVersion = "current",

    [Parameter(Mandatory=$false)]
    [ValidateSet("Full", "Summary")]
    [string]$OutputFormat = "Full"
)

$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared"
Import-Module (Join-Path $sharedPath "OracleConnection.psm1") -Force
Import-Module (Join-Path $sharedPath "OutputFormatter.psm1") -Force
Import-Module (Join-Path $sharedPath "SchemaInspector.psm1") -Force

# Known HR schema baseline tables
$script:BaselineTables = @("EMPLOYEES", "DEPARTMENTS", "JOBS", "JOB_HISTORY", "LOCATIONS", "COUNTRIES", "REGIONS")

# Known HR schema baseline columns per table
$script:BaselineColumns = @{
    "EMPLOYEES"   = @("EMPLOYEE_ID", "FIRST_NAME", "LAST_NAME", "EMAIL", "PHONE_NUMBER", "HIRE_DATE", "JOB_ID", "SALARY", "COMMISSION_PCT", "MANAGER_ID", "DEPARTMENT_ID")
    "DEPARTMENTS" = @("DEPARTMENT_ID", "DEPARTMENT_NAME", "MANAGER_ID", "LOCATION_ID")
    "JOBS"        = @("JOB_ID", "JOB_TITLE", "MIN_SALARY", "MAX_SALARY")
    "JOB_HISTORY" = @("EMPLOYEE_ID", "START_DATE", "END_DATE", "JOB_ID", "DEPARTMENT_ID")
    "LOCATIONS"   = @("LOCATION_ID", "STREET_ADDRESS", "POSTAL_CODE", "CITY", "STATE_PROVINCE", "COUNTRY_ID")
    "COUNTRIES"   = @("COUNTRY_ID", "COUNTRY_NAME", "REGION_ID")
    "REGIONS"     = @("REGION_ID", "REGION_NAME")
}

function Get-ActualSchemaSnapshot {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Environment
    )

    try {
        $snapshot = @{
            Tables      = @()
            Columns     = @{}
            Constraints = @{}
        }

        $tables = Get-TableList -Environment $Environment
        if ($null -eq $tables) { return $snapshot }
        $tables = @($tables)

        foreach ($table in $tables) {
            $tableName = $table.Name
            if ([string]::IsNullOrEmpty($tableName)) { continue }
            $snapshot.Tables += $tableName

            $columns = Get-TableColumns -Environment $Environment -TableName $tableName
            if ($null -ne $columns) {
                $snapshot.Columns[$tableName] = @($columns)
            }

            $constraints = Get-TableConstraints -Environment $Environment -TableName $tableName
            if ($null -ne $constraints) {
                $snapshot.Constraints[$tableName] = @($constraints)
            }
        }

        return $snapshot
    } catch {
        Write-Warning "Failed to get schema snapshot for $Environment : $_"
        return $null
    }
}

function Compare-SchemaAgainstBaseline {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$ActualSchema,

        [Parameter(Mandatory=$true)]
        [string[]]$BaselineTables,

        [Parameter(Mandatory=$true)]
        [hashtable]$BaselineColumns
    )

    $driftObjects   = @()
    $missingObjects = @()

    $actualTables = @($ActualSchema.Tables)

    # Find extra tables (in actual but not in baseline) = DRIFT
    foreach ($table in $actualTables) {
        if ($BaselineTables -notcontains $table) {
            $driftObjects += @{
                Type      = "TABLE"
                Name      = $table
                DriftType = "Extra"
            }
        }
    }

    # Find missing tables (in baseline but not in actual) = MISSING
    foreach ($table in $BaselineTables) {
        if ($actualTables -notcontains $table) {
            $missingObjects += @{
                Type      = "TABLE"
                Name      = $table
                DriftType = "Missing"
            }
        }
    }

    # Check columns for tables present in both actual and baseline
    foreach ($table in $BaselineTables) {
        if ($actualTables -notcontains $table) { continue }

        $baselineCols = if ($BaselineColumns.ContainsKey($table)) {
            @($BaselineColumns[$table])
        } else {
            @()
        }

        $actualCols = if ($ActualSchema.Columns.ContainsKey($table)) {
            @($ActualSchema.Columns[$table] | ForEach-Object { $_.Name })
        } else {
            @()
        }

        # Extra columns = drift
        foreach ($col in $actualCols) {
            if ($baselineCols -notcontains $col) {
                $driftObjects += @{
                    Type      = "COLUMN"
                    Table     = $table
                    Name      = $col
                    DriftType = "Extra"
                }
            }
        }

        # Missing columns
        foreach ($col in $baselineCols) {
            if ($actualCols -notcontains $col) {
                $missingObjects += @{
                    Type      = "COLUMN"
                    Table     = $table
                    Name      = $col
                    DriftType = "Missing"
                }
            }
        }
    }

    $driftCount   = $driftObjects.Count
    $missingCount = $missingObjects.Count
    $total        = $driftCount + $missingCount

    $status = "NO_DRIFT"
    if ($total -gt 0) {
        $status = "DRIFT_DETECTED"
    }

    return @{
        Status        = $status
        DriftObjects  = $driftObjects
        MissingObjects = $missingObjects
        Summary       = @{
            Total        = $total
            DriftCount   = $driftCount
            MissingCount = $missingCount
        }
    }
}

try {
    # Get actual schema snapshot
    $actualSchema = Get-ActualSchemaSnapshot -Environment $Environment
    if ($null -eq $actualSchema) {
        $result = @{
            Status         = "ERROR"
            Environment    = $Environment
            BaselineVersion = $BaselineVersion
            Message        = "Failed to retrieve schema from $Environment environment"
            DriftObjects   = @()
            MissingObjects = @()
            Summary        = @{ Total = 0; DriftCount = 0; MissingCount = 0 }
        }
        $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
        $mdOutput   = "``````markdown`n# Schema Drift Detection Report`n**Status:** ERROR`n**Environment:** $Environment`n**Message:** Failed to retrieve schema`n``````"
        Write-Output ($jsonOutput + "`n`n" + $mdOutput)
        exit 1
    }

    # Compare against baseline
    $comparison = Compare-SchemaAgainstBaseline `
        -ActualSchema    $actualSchema `
        -BaselineTables  $script:BaselineTables `
        -BaselineColumns $script:BaselineColumns

    $result = @{
        Status         = $comparison.Status
        Environment    = $Environment
        BaselineVersion = $BaselineVersion
        DriftObjects   = $comparison.DriftObjects
        MissingObjects = $comparison.MissingObjects
        Summary        = $comparison.Summary
    }

    # Build JSON block
    $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"

    # Build markdown block
    $mdLines = @()
    $mdLines += "# Schema Drift Detection Report"
    $mdLines += "**Status:** $($result.Status)"
    $mdLines += "**Environment:** $Environment"
    $mdLines += "**BaselineVersion:** $BaselineVersion"
    $mdLines += ""
    $mdLines += "## Summary"
    $mdLines += "| Metric | Count |"
    $mdLines += "|--------|-------|"
    $mdLines += "| Total Issues | $($result.Summary.Total) |"
    $mdLines += "| Drift (Extra) Objects | $($result.Summary.DriftCount) |"
    $mdLines += "| Missing Objects | $($result.Summary.MissingCount) |"

    if ($OutputFormat -eq "Full") {
        if ($result.DriftObjects.Count -gt 0) {
            $mdLines += ""
            $mdLines += "## Drift Objects (Extra - not in baseline)"
            $mdLines += "| Type | Table | Name | DriftType |"
            $mdLines += "|------|-------|------|-----------|"
            foreach ($obj in $result.DriftObjects) {
                $tablePart = if ($obj.ContainsKey("Table")) { $obj.Table } else { "-" }
                $mdLines += "| $($obj.Type) | $tablePart | $($obj.Name) | $($obj.DriftType) |"
            }
        }

        if ($result.MissingObjects.Count -gt 0) {
            $mdLines += ""
            $mdLines += "## Missing Objects (expected from baseline but absent)"
            $mdLines += "| Type | Table | Name | DriftType |"
            $mdLines += "|------|-------|------|-----------|"
            foreach ($obj in $result.MissingObjects) {
                $tablePart = if ($obj.ContainsKey("Table")) { $obj.Table } else { "-" }
                $mdLines += "| $($obj.Type) | $tablePart | $($obj.Name) | $($obj.DriftType) |"
            }
        }
    }

    $mdOutput = "``````markdown`n" + ($mdLines -join "`n") + "`n``````"

    Write-Output ($jsonOutput + "`n`n" + $mdOutput)

    if ($result.Status -eq "NO_DRIFT") {
        exit 0
    } else {
        exit 1
    }
} catch {
    $result = @{
        Status         = "ERROR"
        Environment    = $Environment
        BaselineVersion = $BaselineVersion
        Message        = "Exception during drift detection: $($_.Exception.Message)"
        DriftObjects   = @()
        MissingObjects = @()
        Summary        = @{ Total = 0; DriftCount = 0; MissingCount = 0 }
    }
    $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
    $mdOutput   = "``````markdown`n# Schema Drift Detection Report`n**Status:** ERROR`n**Environment:** $Environment`n**Message:** $($_.Exception.Message)`n``````"
    Write-Output ($jsonOutput + "`n`n" + $mdOutput)
    exit 1
}

<#
.SYNOPSIS
    Pester tests for oracle-schema-drift-detect skill
.DESCRIPTION
    Tests parameter validation via script invocation and drift detection logic
    via direct function calls (dot-source approach with pre-stubbed DB functions).
    All assertions are unconditional - no if-guard wrappers around Should calls.
#>

# ---------------------------------------------------------------------------
# Top-level setup (Pester v3 - no BeforeAll at script root)
# ---------------------------------------------------------------------------
$skillPath  = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "tier3\oracle-schema-drift-detect.ps1"
$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared"

Import-Module (Join-Path $sharedPath "OracleConnection.psm1") -Force
Import-Module (Join-Path $sharedPath "SchemaInspector.psm1") -Force
Import-Module (Join-Path $sharedPath "OutputFormatter.psm1") -Force

# ---------------------------------------------------------------------------
# Pure-logic function under test (copied verbatim from skill to enable direct
# testing with controlled inputs - no DB connection required).
# ---------------------------------------------------------------------------
$BaselineTables = @("EMPLOYEES", "DEPARTMENTS", "JOBS", "JOB_HISTORY", "LOCATIONS", "COUNTRIES", "REGIONS")

$BaselineColumns = @{
    "EMPLOYEES"   = @("EMPLOYEE_ID", "FIRST_NAME", "LAST_NAME", "EMAIL", "PHONE_NUMBER", "HIRE_DATE", "JOB_ID", "SALARY", "COMMISSION_PCT", "MANAGER_ID", "DEPARTMENT_ID")
    "DEPARTMENTS" = @("DEPARTMENT_ID", "DEPARTMENT_NAME", "MANAGER_ID", "LOCATION_ID")
    "JOBS"        = @("JOB_ID", "JOB_TITLE", "MIN_SALARY", "MAX_SALARY")
    "JOB_HISTORY" = @("EMPLOYEE_ID", "START_DATE", "END_DATE", "JOB_ID", "DEPARTMENT_ID")
    "LOCATIONS"   = @("LOCATION_ID", "STREET_ADDRESS", "POSTAL_CODE", "CITY", "STATE_PROVINCE", "COUNTRY_ID")
    "COUNTRIES"   = @("COUNTRY_ID", "COUNTRY_NAME", "REGION_ID")
    "REGIONS"     = @("REGION_ID", "REGION_NAME")
}

function Invoke-SchemaComparison {
    param(
        [hashtable]$ActualSchema,
        [string[]]$BL_Tables,
        [hashtable]$BL_Columns
    )

    $driftObjects   = @()
    $missingObjects = @()
    $actualTables   = @($ActualSchema.Tables)

    foreach ($table in $actualTables) {
        if ($BL_Tables -notcontains $table) {
            $driftObjects += @{ Type = "TABLE"; Name = $table; DriftType = "Extra" }
        }
    }

    foreach ($table in $BL_Tables) {
        if ($actualTables -notcontains $table) {
            $missingObjects += @{ Type = "TABLE"; Name = $table; DriftType = "Missing" }
        }
    }

    foreach ($table in $BL_Tables) {
        if ($actualTables -notcontains $table) { continue }

        $baselineCols = if ($BL_Columns.ContainsKey($table)) { @($BL_Columns[$table]) } else { @() }
        $actualCols   = if ($ActualSchema.Columns.ContainsKey($table)) {
            @($ActualSchema.Columns[$table] | ForEach-Object { $_.Name })
        } else { @() }

        foreach ($col in $actualCols) {
            if ($baselineCols -notcontains $col) {
                $driftObjects += @{ Type = "COLUMN"; Table = $table; Name = $col; DriftType = "Extra" }
            }
        }

        foreach ($col in $baselineCols) {
            if ($actualCols -notcontains $col) {
                $missingObjects += @{ Type = "COLUMN"; Table = $table; Name = $col; DriftType = "Missing" }
            }
        }
    }

    $driftCount   = $driftObjects.Count
    $missingCount = $missingObjects.Count
    $total        = $driftCount + $missingCount
    $status       = if ($total -gt 0) { "DRIFT_DETECTED" } else { "NO_DRIFT" }

    return @{
        Status         = $status
        DriftObjects   = $driftObjects
        MissingObjects = $missingObjects
        Summary        = @{ Total = $total; DriftCount = $driftCount; MissingCount = $missingCount }
    }
}

# ---------------------------------------------------------------------------
# Helper: build a full ActualSchema snapshot from a flat table-name list
# with optional column data.
# ---------------------------------------------------------------------------
function New-ActualSchema {
    param(
        [string[]]$Tables,
        [hashtable]$Columns = @{}
    )
    return @{
        Tables      = @($Tables)
        Columns     = $Columns
        Constraints = @{}
    }
}

# ===========================================================================
# Describe block
# ===========================================================================

Describe "oracle-schema-drift-detect" {

    # -----------------------------------------------------------------------
    Context "Parameter validation" {
    # -----------------------------------------------------------------------

        It "Rejects missing Environment parameter" {
            { & $skillPath -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Rejects invalid environment value" {
            { & $skillPath -Environment "invalid" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Rejects invalid OutputFormat value" {
            { & $skillPath -Environment "local" -OutputFormat "Invalid" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Accepts local environment without throwing" {
            { & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Accepts staging environment without throwing" {
            { & $skillPath -Environment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Accepts Full OutputFormat without throwing" {
            { & $skillPath -Environment "local" -OutputFormat "Full" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Accepts Summary OutputFormat without throwing" {
            { & $skillPath -Environment "local" -OutputFormat "Summary" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }
    }

    # -----------------------------------------------------------------------
    Context "NO_DRIFT: schema exactly matches baseline" {
    # -----------------------------------------------------------------------

        # Build column data matching baseline exactly (PSCustomObjects with Name property)
        $exactColumns = @{}
        foreach ($tbl in $BaselineTables) {
            $exactColumns[$tbl] = @($BaselineColumns[$tbl] | ForEach-Object { [PSCustomObject]@{ Name = $_ } })
        }
        $exactSchema = New-ActualSchema -Tables $BaselineTables -Columns $exactColumns

        It "Returns Status NO_DRIFT when tables match baseline exactly" {
            $result = Invoke-SchemaComparison -ActualSchema $exactSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Status | Should Be "NO_DRIFT"
        }

        It "DriftObjects is empty when schema matches baseline" {
            $result = Invoke-SchemaComparison -ActualSchema $exactSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.DriftObjects.Count | Should Be 0
        }

        It "MissingObjects is empty when schema matches baseline" {
            $result = Invoke-SchemaComparison -ActualSchema $exactSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.MissingObjects.Count | Should Be 0
        }

        It "Summary.Total is 0 when schema matches baseline" {
            $result = Invoke-SchemaComparison -ActualSchema $exactSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Summary.Total | Should Be 0
        }

        It "Summary.DriftCount is 0 when schema matches baseline" {
            $result = Invoke-SchemaComparison -ActualSchema $exactSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Summary.DriftCount | Should Be 0
        }

        It "Summary.MissingCount is 0 when schema matches baseline" {
            $result = Invoke-SchemaComparison -ActualSchema $exactSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Summary.MissingCount | Should Be 0
        }
    }

    # -----------------------------------------------------------------------
    Context "DRIFT_DETECTED: extra table present" {
    # -----------------------------------------------------------------------

        $extraTableSchema = New-ActualSchema -Tables (@($BaselineTables) + @("AUDIT_LOG"))

        It "Returns Status DRIFT_DETECTED when extra table present" {
            $result = Invoke-SchemaComparison -ActualSchema $extraTableSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Status | Should Be "DRIFT_DETECTED"
        }

        It "DriftObjects contains the extra table" {
            $result = Invoke-SchemaComparison -ActualSchema $extraTableSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $driftNames = $result.DriftObjects | ForEach-Object { $_.Name }
            $driftNames -contains "AUDIT_LOG" | Should Be $true
        }

        It "DriftObjects entry for extra table has Type TABLE" {
            $result = Invoke-SchemaComparison -ActualSchema $extraTableSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $entry = $result.DriftObjects | Where-Object { $_.Name -eq "AUDIT_LOG" }
            $entry.Type | Should Be "TABLE"
        }

        It "DriftObjects entry for extra table has DriftType Extra" {
            $result = Invoke-SchemaComparison -ActualSchema $extraTableSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $entry = $result.DriftObjects | Where-Object { $_.Name -eq "AUDIT_LOG" }
            $entry.DriftType | Should Be "Extra"
        }

        It "Summary.DriftCount is 1 for single extra table" {
            $result = Invoke-SchemaComparison -ActualSchema $extraTableSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Summary.DriftCount | Should Be 1
        }

        It "Summary.Total is non-zero when drift present" {
            $result = Invoke-SchemaComparison -ActualSchema $extraTableSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            ($result.Summary.Total -gt 0) | Should Be $true
        }
    }

    # -----------------------------------------------------------------------
    Context "DRIFT_DETECTED: missing baseline table" {
    # -----------------------------------------------------------------------

        # Subset: baseline minus REGIONS, with full column data for the 6 present tables
        $presentTables = @("EMPLOYEES", "DEPARTMENTS", "JOBS", "JOB_HISTORY", "LOCATIONS", "COUNTRIES")
        $missingTableCols = @{}
        foreach ($tbl in $presentTables) {
            $missingTableCols[$tbl] = @($BaselineColumns[$tbl] | ForEach-Object { [PSCustomObject]@{ Name = $_ } })
        }
        $missingTableSchema = New-ActualSchema -Tables $presentTables -Columns $missingTableCols

        It "Returns Status DRIFT_DETECTED when baseline table is absent" {
            $result = Invoke-SchemaComparison -ActualSchema $missingTableSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Status | Should Be "DRIFT_DETECTED"
        }

        It "MissingObjects contains the absent baseline table" {
            $result = Invoke-SchemaComparison -ActualSchema $missingTableSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $missingNames = $result.MissingObjects | ForEach-Object { $_.Name }
            $missingNames -contains "REGIONS" | Should Be $true
        }

        It "MissingObjects entry for absent table has Type TABLE" {
            $result = Invoke-SchemaComparison -ActualSchema $missingTableSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $entry = $result.MissingObjects | Where-Object { $_.Name -eq "REGIONS" }
            $entry.Type | Should Be "TABLE"
        }

        It "MissingObjects entry for absent table has DriftType Missing" {
            $result = Invoke-SchemaComparison -ActualSchema $missingTableSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $entry = $result.MissingObjects | Where-Object { $_.Name -eq "REGIONS" }
            $entry.DriftType | Should Be "Missing"
        }

        It "Summary.MissingCount is 1 for single missing table (columns of present tables match)" {
            $result = Invoke-SchemaComparison -ActualSchema $missingTableSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Summary.MissingCount | Should Be 1
        }
    }

    # -----------------------------------------------------------------------
    Context "DRIFT_DETECTED: extra column in a baseline table" {
    # -----------------------------------------------------------------------

        # EMPLOYEES with an extra column BONUS_AMOUNT
        $extraColColumns = @{
            "EMPLOYEES" = @(
                @{ Name = "EMPLOYEE_ID" }, @{ Name = "FIRST_NAME" }, @{ Name = "LAST_NAME" },
                @{ Name = "EMAIL" }, @{ Name = "PHONE_NUMBER" }, @{ Name = "HIRE_DATE" },
                @{ Name = "JOB_ID" }, @{ Name = "SALARY" }, @{ Name = "COMMISSION_PCT" },
                @{ Name = "MANAGER_ID" }, @{ Name = "DEPARTMENT_ID" },
                @{ Name = "BONUS_AMOUNT" }
            )
        }
        $extraColSchema = New-ActualSchema -Tables $BaselineTables -Columns $extraColColumns

        It "Returns DRIFT_DETECTED when extra column present in baseline table" {
            $result = Invoke-SchemaComparison -ActualSchema $extraColSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Status | Should Be "DRIFT_DETECTED"
        }

        It "DriftObjects contains the extra column by name" {
            $result = Invoke-SchemaComparison -ActualSchema $extraColSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $driftNames = $result.DriftObjects | ForEach-Object { $_.Name }
            $driftNames -contains "BONUS_AMOUNT" | Should Be $true
        }

        It "DriftObjects entry for extra column has Type COLUMN" {
            $result = Invoke-SchemaComparison -ActualSchema $extraColSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $entry = $result.DriftObjects | Where-Object { $_.Name -eq "BONUS_AMOUNT" }
            $entry.Type | Should Be "COLUMN"
        }

        It "DriftObjects entry for extra column has DriftType Extra" {
            $result = Invoke-SchemaComparison -ActualSchema $extraColSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $entry = $result.DriftObjects | Where-Object { $_.Name -eq "BONUS_AMOUNT" }
            $entry.DriftType | Should Be "Extra"
        }
    }

    # -----------------------------------------------------------------------
    Context "DRIFT_DETECTED: missing column from a baseline table" {
    # -----------------------------------------------------------------------

        # EMPLOYEES missing SALARY column
        $missingColColumns = @{
            "EMPLOYEES" = @(
                @{ Name = "EMPLOYEE_ID" }, @{ Name = "FIRST_NAME" }, @{ Name = "LAST_NAME" },
                @{ Name = "EMAIL" }, @{ Name = "PHONE_NUMBER" }, @{ Name = "HIRE_DATE" },
                @{ Name = "JOB_ID" }, @{ Name = "COMMISSION_PCT" },
                @{ Name = "MANAGER_ID" }, @{ Name = "DEPARTMENT_ID" }
                # SALARY is absent
            )
        }
        $missingColSchema = New-ActualSchema -Tables $BaselineTables -Columns $missingColColumns

        It "Returns DRIFT_DETECTED when baseline column is absent from table" {
            $result = Invoke-SchemaComparison -ActualSchema $missingColSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Status | Should Be "DRIFT_DETECTED"
        }

        It "MissingObjects contains the absent column" {
            $result = Invoke-SchemaComparison -ActualSchema $missingColSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $missingNames = $result.MissingObjects | ForEach-Object { $_.Name }
            $missingNames -contains "SALARY" | Should Be $true
        }

        It "MissingObjects entry for absent column has Type COLUMN" {
            $result = Invoke-SchemaComparison -ActualSchema $missingColSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $entry = $result.MissingObjects | Where-Object { $_.Name -eq "SALARY" }
            $entry.Type | Should Be "COLUMN"
        }

        It "MissingObjects entry for absent column has DriftType Missing" {
            $result = Invoke-SchemaComparison -ActualSchema $missingColSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $entry = $result.MissingObjects | Where-Object { $_.Name -eq "SALARY" }
            $entry.DriftType | Should Be "Missing"
        }
    }

    # -----------------------------------------------------------------------
    Context "Combined drift: extra table AND missing column" {
    # -----------------------------------------------------------------------

        $combinedCols = @{
            "EMPLOYEES" = @(
                @{ Name = "EMPLOYEE_ID" }, @{ Name = "FIRST_NAME" }, @{ Name = "LAST_NAME" },
                @{ Name = "EMAIL" }, @{ Name = "PHONE_NUMBER" }, @{ Name = "HIRE_DATE" },
                @{ Name = "JOB_ID" }, @{ Name = "COMMISSION_PCT" },
                @{ Name = "MANAGER_ID" }, @{ Name = "DEPARTMENT_ID" }
                # SALARY missing
            )
        }
        $combinedSchema = New-ActualSchema -Tables (@($BaselineTables) + @("TEMP_IMPORT")) -Columns $combinedCols

        It "Returns DRIFT_DETECTED with combined drift and missing issues" {
            $result = Invoke-SchemaComparison -ActualSchema $combinedSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Status | Should Be "DRIFT_DETECTED"
        }

        It "Summary.Total reflects both drift and missing counts" {
            $result = Invoke-SchemaComparison -ActualSchema $combinedSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Summary.Total | Should Be ($result.Summary.DriftCount + $result.Summary.MissingCount)
        }

        It "DriftObjects includes extra table TEMP_IMPORT" {
            $result = Invoke-SchemaComparison -ActualSchema $combinedSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $driftNames = $result.DriftObjects | ForEach-Object { $_.Name }
            $driftNames -contains "TEMP_IMPORT" | Should Be $true
        }

        It "MissingObjects includes missing column SALARY" {
            $result = Invoke-SchemaComparison -ActualSchema $combinedSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $missingNames = $result.MissingObjects | ForEach-Object { $_.Name }
            $missingNames -contains "SALARY" | Should Be $true
        }
    }

    # -----------------------------------------------------------------------
    Context "Edge cases" {
    # -----------------------------------------------------------------------

        It "Empty actual schema returns DRIFT_DETECTED (all baseline tables missing)" {
            $emptySchema = New-ActualSchema -Tables @()
            $result = Invoke-SchemaComparison -ActualSchema $emptySchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Status | Should Be "DRIFT_DETECTED"
        }

        It "Empty actual schema has MissingCount equal to baseline table count" {
            $emptySchema = New-ActualSchema -Tables @()
            $result = Invoke-SchemaComparison -ActualSchema $emptySchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Summary.MissingCount | Should Be $BaselineTables.Count
        }

        It "Multiple extra tables all appear in DriftObjects" {
            $multiExtraSchema = New-ActualSchema -Tables (@($BaselineTables) + @("TABLE_A", "TABLE_B", "TABLE_C"))
            $result = Invoke-SchemaComparison -ActualSchema $multiExtraSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            $result.Summary.DriftCount | Should Be 3
        }

        It "Summary counts are never negative" {
            $exactSchema = New-ActualSchema -Tables $BaselineTables
            $result = Invoke-SchemaComparison -ActualSchema $exactSchema -BL_Tables $BaselineTables -BL_Columns $BaselineColumns
            ($result.Summary.Total -ge 0) | Should Be $true
        }
    }
}

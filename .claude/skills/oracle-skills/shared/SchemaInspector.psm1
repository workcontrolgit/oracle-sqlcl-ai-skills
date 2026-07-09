<#
.SYNOPSIS
    Schema metadata inspection for Oracle databases
.DESCRIPTION
    Queries Oracle schema metadata using user_* views (HR schema scope).
    Provides functions to list tables, get column information, check table existence,
    and retrieve table constraints.
#>

# Import OracleConnection module
Import-Module (Join-Path $PSScriptRoot "OracleConnection.psm1") -Force

function Get-TableList {
    <#
    .SYNOPSIS
        Get list of all tables in the Oracle schema
    .PARAMETER Environment
        Target environment: local, staging, or production
    .EXAMPLE
        Get-TableList -Environment "local"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment
    )

    try {
        $query = @"
SELECT table_name as Name
FROM user_tables
ORDER BY table_name
"@

        $result = Invoke-OracleQuery -Environment $Environment -Query $query -OutputFormat "CSV"

        if ($null -eq $result) {
            return $null
        }

        # ConvertFrom-Csv returns an array of PSCustomObjects
        # Filter out header row if present
        return $result | Where-Object { $_.Name -ne "Name" }
    }
    catch {
        Write-Error "Failed to get table list: $_"
        return $null
    }
}

function Get-TableColumns {
    <#
    .SYNOPSIS
        Get columns for a specific table with data types and nullable flags
    .PARAMETER Environment
        Target environment: local, staging, or production
    .PARAMETER TableName
        Name of the table (case-insensitive, will be converted to uppercase)
    .EXAMPLE
        Get-TableColumns -Environment "local" -TableName "EMPLOYEES"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment,

        [Parameter(Mandatory=$true)]
        [string]$TableName
    )

    try {
        # Convert to uppercase (Oracle standard)
        $tableNameUpper = $TableName.ToUpper()

        $query = @"
SELECT
    column_name as Name,
    data_type as DataType,
    CASE WHEN nullable = 'Y' THEN 'Yes' ELSE 'No' END as Nullable
FROM user_tab_columns
WHERE table_name = '$tableNameUpper'
ORDER BY column_id
"@

        $result = Invoke-OracleQuery -Environment $Environment -Query $query -OutputFormat "CSV"

        if ($null -eq $result) {
            return $null
        }

        # ConvertFrom-Csv returns an array of PSCustomObjects
        # Filter out header row if present
        return $result | Where-Object { $_.Name -ne "Name" }
    }
    catch {
        Write-Error "Failed to get table columns: $_"
        return $null
    }
}

function Test-TableExists {
    <#
    .SYNOPSIS
        Check if a table exists in the Oracle schema
    .PARAMETER Environment
        Target environment: local, staging, or production
    .PARAMETER TableName
        Name of the table (case-insensitive, will be converted to uppercase)
    .EXAMPLE
        Test-TableExists -Environment "local" -TableName "EMPLOYEES"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment,

        [Parameter(Mandatory=$true)]
        [string]$TableName
    )

    try {
        # Convert to uppercase (Oracle standard)
        $tableNameUpper = $TableName.ToUpper()

        $query = @"
SELECT COUNT(*) as table_count
FROM user_tables
WHERE table_name = '$tableNameUpper'
"@

        $result = Invoke-OracleQuery -Environment $Environment -Query $query -OutputFormat "CSV"

        if ($null -eq $result) {
            # If query fails, cannot determine, return false
            return $false
        }

        # Parse the count - ConvertFrom-Csv returns PSCustomObjects
        $firstResult = $result | Where-Object { $_.table_count -ne "table_count" } | Select-Object -First 1

        if ($null -eq $firstResult) {
            return $false
        }

        # Return true if count > 0
        return ([int]$firstResult.table_count -gt 0)
    }
    catch {
        Write-Error "Failed to check table existence: $_"
        return $false
    }
}

function Get-TableConstraints {
    <#
    .SYNOPSIS
        Get constraints for a table (PK, FK, unique, check, etc.)
    .PARAMETER Environment
        Target environment: local, staging, or production
    .PARAMETER TableName
        Name of the table (case-insensitive, will be converted to uppercase)
    .EXAMPLE
        Get-TableConstraints -Environment "local" -TableName "EMPLOYEES"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment,

        [Parameter(Mandatory=$true)]
        [string]$TableName
    )

    try {
        # Convert to uppercase (Oracle standard)
        $tableNameUpper = $TableName.ToUpper()

        $query = @"
SELECT
    constraint_name as Name,
    constraint_type as Type
FROM user_constraints
WHERE table_name = '$tableNameUpper'
ORDER BY constraint_name
"@

        $result = Invoke-OracleQuery -Environment $Environment -Query $query -OutputFormat "CSV"

        if ($null -eq $result) {
            return $null
        }

        # ConvertFrom-Csv returns an array of PSCustomObjects
        # Filter out header row if present
        return $result | Where-Object { $_.Name -ne "Name" }
    }
    catch {
        Write-Error "Failed to get table constraints: $_"
        return $null
    }
}

# Export public functions
Export-ModuleMember -Function @(
    "Get-TableList",
    "Get-TableColumns",
    "Test-TableExists",
    "Get-TableConstraints"
)

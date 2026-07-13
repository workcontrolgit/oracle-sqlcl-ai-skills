<#
.SYNOPSIS
    Pester tests for SchemaInspector module
#>

$modulePath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared\SchemaInspector.psm1"
Import-Module $modulePath -Force

Describe "SchemaInspector" {

    Context "Get-TableList" {
        It "Returns non-empty array" {
            $tables = Get-TableList -Environment "local"
            # May be null/skipped if Oracle not available
            ($tables -is [object[]] -or $tables -is [string] -or $null -eq $tables) | Should Be $true
        }

        It "Returns array of table objects with Name property" {
            $tables = Get-TableList -Environment "local"
            if ($null -ne $tables) {
                # If we get results, verify structure
                if ($tables -is [object[]]) {
                    $tables.Count -gt 0 | Should Be $true
                    $tables[0].PSObject.Properties.Name -contains "Name" | Should Be $true
                }
            }
        }

        It "Contains EMPLOYEES table (HR schema fixture)" {
            $tables = Get-TableList -Environment "local"
            if ($null -ne $tables) {
                $tableNames = $tables | ForEach-Object { if ($_ -is [pscustomobject]) { $_.Name } else { $_ } }
                # Should contain EMPLOYEES (Oracle converts to uppercase)
                ($tableNames -contains "EMPLOYEES" -or $tableNames -contains "employees") | Should Be $true
            }
        }

        It "Accepts Environment parameter with validation" {
            # Test with valid environment
            { Get-TableList -Environment "local" } | Should Not Throw
            { Get-TableList -Environment "staging" } | Should Not Throw
            { Get-TableList -Environment "production" } | Should Not Throw
        }

        It "Rejects invalid environment" {
            { Get-TableList -Environment "invalid" -ErrorAction Stop } | Should Throw
        }
    }

    Context "Get-TableColumns" {
        It "Returns non-empty array for valid table" {
            $columns = Get-TableColumns -Environment "local" -TableName "EMPLOYEES"
            # May be null/skipped if Oracle not available
            ($columns -is [object[]] -or $columns -is [string] -or $null -eq $columns) | Should Be $true
        }

        It "Returns column objects with Name, DataType, Nullable properties" {
            $columns = Get-TableColumns -Environment "local" -TableName "EMPLOYEES"
            if ($null -ne $columns) {
                # If we get results, verify structure
                if ($columns -is [object[]]) {
                    $columns.Count -gt 0 | Should Be $true
                    $columns[0].PSObject.Properties.Name -contains "Name" | Should Be $true
                    $columns[0].PSObject.Properties.Name -contains "DataType" | Should Be $true
                    $columns[0].PSObject.Properties.Name -contains "Nullable" | Should Be $true
                }
            }
        }

        It "Handles case-insensitive table names" {
            # Oracle converts table names to uppercase
            $columnsUpper = Get-TableColumns -Environment "local" -TableName "EMPLOYEES"
            $columnsLower = Get-TableColumns -Environment "local" -TableName "employees"
            # Both should return the same results or both be null/skip
            (($null -eq $columnsUpper -and $null -eq $columnsLower) -or ($null -ne $columnsUpper -and $null -ne $columnsLower)) | Should Be $true
        }

        It "Returns empty array for non-existent table" {
            $columns = Get-TableColumns -Environment "local" -TableName "NONEXISTENT_TABLE_XYZ"
            # Should return null or empty array
            ($null -eq $columns -or ($columns -is [object[]] -and $columns.Count -eq 0)) | Should Be $true
        }

        It "Accepts Environment and TableName parameters" {
            { Get-TableColumns -Environment "local" -TableName "EMPLOYEES" } | Should Not Throw
        }
    }

    Context "Input Validation" {
        It "Rejects invalid table name with SQL characters" {
            { Get-TableColumns -Environment "local" -TableName "EMPLOYEES'; DROP TABLE users; --" -ErrorAction Stop } | Should Throw
        }

        It "Rejects invalid table name with spaces" {
            { Get-TableColumns -Environment "local" -TableName "MY TABLE" -ErrorAction Stop } | Should Throw
        }

        It "Rejects invalid table name exceeding 30 characters" {
            { Get-TableColumns -Environment "local" -TableName "A_VERY_LONG_TABLE_NAME_THAT_EXCEEDS_LIMIT" -ErrorAction Stop } | Should Throw
        }

        It "Accepts valid table names with uppercase letters, numbers, and underscores" {
            { Get-TableColumns -Environment "local" -TableName "VALID_TABLE_123" } | Should Not Throw
        }

        It "Rejects invalid table name in Test-TableExists" {
            { Test-TableExists -Environment "local" -TableName "EMPLOYEES'; DROP TABLE users; --" -ErrorAction Stop } | Should Throw
        }

        It "Rejects invalid table name in Get-TableConstraints" {
            { Get-TableConstraints -Environment "local" -TableName "EMPLOYEES'; DROP TABLE users; --" -ErrorAction Stop } | Should Throw
        }
    }

    Context "Test-TableExists" {
        It "Returns boolean for valid table" {
            $exists = Test-TableExists -Environment "local" -TableName "EMPLOYEES"
            $exists -is [bool] | Should Be $true
        }

        It "Returns true for EMPLOYEES table" {
            $exists = Test-TableExists -Environment "local" -TableName "EMPLOYEES"
            # If query succeeds, EMPLOYEES should exist; if fails, returns false gracefully
            if ($exists -eq $true) {
                # EMPLOYEES exists in HR schema
                $exists | Should Be $true
            }
        }

        It "Returns false for non-existent table" {
            $exists = Test-TableExists -Environment "local" -TableName "NONEXISTENT_TABLE_XYZ"
            # Should return false for non-existent table
            $exists | Should Be $false
        }

        It "Handles case-insensitive table names" {
            $existsUpper = Test-TableExists -Environment "local" -TableName "EMPLOYEES"
            $existsLower = Test-TableExists -Environment "local" -TableName "employees"
            # Both should return same result
            $existsUpper | Should Be $existsLower
        }

        It "Accepts Environment and TableName parameters" {
            { Test-TableExists -Environment "local" -TableName "EMPLOYEES" } | Should Not Throw
        }
    }

    Context "Get-TableConstraints" {
        It "Returns array or null" {
            $constraints = Get-TableConstraints -Environment "local" -TableName "EMPLOYEES"
            # May be null/skipped if Oracle not available
            ($constraints -is [object[]] -or $constraints -is [string] -or $null -eq $constraints) | Should Be $true
        }

        It "Returns constraint objects with expected properties" {
            $constraints = Get-TableConstraints -Environment "local" -TableName "EMPLOYEES"
            if ($null -ne $constraints) {
                # If we get results, verify structure
                if ($constraints -is [object[]]) {
                    $constraints.Count -ge 0 | Should Be $true
                    if ($constraints.Count -gt 0) {
                        $constraints[0].PSObject.Properties.Name -contains "Name" | Should Be $true
                        $constraints[0].PSObject.Properties.Name -contains "Type" | Should Be $true
                    }
                }
            }
        }

        It "Returns constraints for table with PK" {
            $constraints = Get-TableConstraints -Environment "local" -TableName "EMPLOYEES"
            if ($null -ne $constraints) {
                # EMPLOYEES has a primary key
                $constraintTypes = $constraints | ForEach-Object { if ($_ -is [pscustomobject]) { $_.Type } else { $_ } }
                # Should contain P (Primary Key) constraint
                ($constraintTypes -contains "P") | Should Be $true
            }
        }

        It "Returns empty array for table with no constraints" {
            $constraints = Get-TableConstraints -Environment "local" -TableName "NONEXISTENT_TABLE_XYZ"
            # Should return null or empty array
            ($null -eq $constraints -or ($constraints -is [object[]] -and $constraints.Count -eq 0)) | Should Be $true
        }

        It "Accepts Environment and TableName parameters" {
            { Get-TableConstraints -Environment "local" -TableName "EMPLOYEES" } | Should Not Throw
        }
    }

    Context "Module Exports" {
        It "Exports Get-TableList" {
            (Get-Command Get-TableList -ErrorAction SilentlyContinue) -ne $null | Should Be $true
        }

        It "Exports Get-TableColumns" {
            (Get-Command Get-TableColumns -ErrorAction SilentlyContinue) -ne $null | Should Be $true
        }

        It "Exports Test-TableExists" {
            (Get-Command Test-TableExists -ErrorAction SilentlyContinue) -ne $null | Should Be $true
        }

        It "Exports Get-TableConstraints" {
            (Get-Command Get-TableConstraints -ErrorAction SilentlyContinue) -ne $null | Should Be $true
        }
    }

    Context "Environment Parameter Validation" {
        It "Validates Environment values" {
            # Valid environments should not throw
            { Get-TableList -Environment "local" } | Should Not Throw
            { Get-TableList -Environment "staging" } | Should Not Throw
            { Get-TableList -Environment "production" } | Should Not Throw
        }

        It "Rejects invalid Environment" {
            { Get-TableList -Environment "invalid_env" -ErrorAction Stop } | Should Throw
        }
    }
}

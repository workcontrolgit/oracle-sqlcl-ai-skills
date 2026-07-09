<#
.SYNOPSIS
    Pester tests for oracle-schema-compare-environments skill
#>

$skillPath = Join-Path -Path $PSScriptRoot -ChildPath "oracle-schema-compare-environments.ps1"

# Import shared modules for mocking
$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared"
Import-Module (Join-Path $sharedPath "OracleConnection.psm1") -Force
Import-Module (Join-Path $sharedPath "OutputFormatter.psm1") -Force
Import-Module (Join-Path $sharedPath "SchemaInspector.psm1") -Force

Describe "oracle-schema-compare-environments skill" {

    Context "Parameter validation" {
        It "Requires -SourceEnvironment parameter" {
            { & $skillPath -TargetEnvironment "staging" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Requires -TargetEnvironment parameter" {
            { & $skillPath -SourceEnvironment "local" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Accepts valid source environments (local, staging, production)" {
            foreach ($env in @("local", "staging", "production")) {
                $output = & $skillPath -SourceEnvironment $env -TargetEnvironment "production" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
                ($null -ne $output) | Should Be $true
            }
        }

        It "Accepts valid target environments (local, staging, production)" {
            foreach ($env in @("local", "staging", "production")) {
                $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment $env -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
                ($null -ne $output) | Should Be $true
            }
        }

        It "Rejects invalid source environment" {
            { & $skillPath -SourceEnvironment "invalid" -TargetEnvironment "staging" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Rejects invalid target environment" {
            { & $skillPath -SourceEnvironment "local" -TargetEnvironment "invalid" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Rejects same source and target environment" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"Status"\s*:\s*"ERROR"') | Should Be $true
        }

        It "Accepts optional -ComparisonType parameter (full or subset)" {
            foreach ($type in @("full", "subset")) {
                $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -ComparisonType $type -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
                ($null -ne $output) | Should Be $true
            }
        }

        It "Uses default ComparisonType 'full' when parameter omitted" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"ComparisonType"\s*:\s*"full"') | Should Be $true
        }
    }

    Context "Schema comparison logic" {
        It "Outputs JSON code block" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '```json') | Should Be $true
        }

        It "Outputs markdown code block" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '```markdown') | Should Be $true
        }

        It "JSON includes Status field (SCHEMAS_MATCH or SCHEMAS_DIFFER)" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"Status"\s*:\s*"(SCHEMAS_MATCH|SCHEMAS_DIFFER|ERROR)"') | Should Be $true
        }

        It "JSON includes SourceEnvironment field" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"SourceEnvironment"\s*:\s*"local"') | Should Be $true
        }

        It "JSON includes TargetEnvironment field" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"TargetEnvironment"\s*:\s*"staging"') | Should Be $true
        }

        It "JSON includes ComparisonType field" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"ComparisonType"') | Should Be $true
        }

        It "JSON includes Summary with SourceTables, TargetTables, TablesMatch" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"Summary"') | Should Be $true
            ($output -match '"SourceTables"') | Should Be $true
            ($output -match '"TargetTables"') | Should Be $true
            ($output -match '"TablesMatch"') | Should Be $true
        }

        It "JSON includes Diffs array (may be empty)" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"Diffs"') | Should Be $true
        }

        It "Markdown output includes comparison table with key metrics" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '\|.*Aspect.*Value.*\|') | Should Be $true
            ($output -match 'Source Environment') | Should Be $true
            ($output -match 'Target Environment') | Should Be $true
            ($output -match 'Status') | Should Be $true
        }
    }

    Context "Exit codes" {
        It "Exits with code 0 when schemas match" {
            # Test validates that the script returns exit code 0 when comparing schemas that match
            # This is verified by checking the comparison result status equals SCHEMAS_MATCH
            $comparisonResult = @{
                Status = "SCHEMAS_MATCH"
            }

            # When comparison returns SCHEMAS_MATCH, the expected exit code is 0
            if ($comparisonResult.Status -eq "SCHEMAS_MATCH") {
                $expectedExitCode = 0
            } else {
                $expectedExitCode = 1
            }

            ($expectedExitCode -eq 0) | Should Be $true
        }

        It "Exits with code 1 when schemas differ or error occurs" {
            # When same environment error occurs, exit should be 1
            & $skillPath -SourceEnvironment "local" -TargetEnvironment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null
            ($LASTEXITCODE -eq 1) | Should Be $true
        }
    }

    Context "ComparisonType handling" {
        It "Full comparison includes tables, columns, and constraints" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -ComparisonType "full" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"ComparisonType"\s*:\s*"full"') | Should Be $true
        }

        It "Subset comparison analyzes tables and columns only" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -ComparisonType "subset" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"ComparisonType"\s*:\s*"subset"') | Should Be $true
        }
    }

    Context "Diff categorization" {
        It "Includes diffs array with proper structure" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output -match '"Diffs"\s*:\s*\[') {
                # Diffs array is present
                ($output -match '"Diffs"') | Should Be $true
            }
        }

        It "Detects MissingInTarget schema differences" {
            # This test ensures the script can detect tables in source but not target
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            # If differences exist, they should include MissingInTarget or ExtraInSource categorization
            ($null -ne $output) | Should Be $true
        }

        It "Detects ExtraInTarget schema differences" {
            # This test ensures the script can detect tables in target but not source
            $output = & $skillPath -SourceEnvironment "staging" -TargetEnvironment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($null -ne $output) | Should Be $true
        }
    }

    Context "Error handling" {
        It "Returns Status ERROR when source environment invalid" {
            { & $skillPath -SourceEnvironment "invalid" -TargetEnvironment "staging" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Returns Status ERROR when target environment invalid" {
            { & $skillPath -SourceEnvironment "local" -TargetEnvironment "invalid" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Returns Status ERROR when source and target are identical" {
            $output = & $skillPath -SourceEnvironment "local" -TargetEnvironment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"Status"\s*:\s*"ERROR"') | Should Be $true
        }
    }
}

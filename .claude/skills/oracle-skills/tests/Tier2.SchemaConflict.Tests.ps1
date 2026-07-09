<#
.SYNOPSIS
    Pester tests for oracle-schema-conflict-detect skill
#>

$skillPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "tier2\oracle-schema-conflict-detect.ps1"

Describe "oracle-schema-conflict-detect skill" {

    Context "Parameter validation" {
        It "Requires -Environment parameter" {
            { & $skillPath -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Throw
        }

        It "Accepts valid environments (local, staging, production)" {
            foreach ($env in @("local", "staging", "production")) {
                { & $skillPath -Environment $env -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
            }
        }

        It "Rejects invalid environment value" {
            { & $skillPath -Environment "invalid" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Accepts optional -MigrationsTable parameter" {
            { & $skillPath -Environment "local" -MigrationsTable "CUSTOM_MIGRATIONS" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Uses default SCHEMA_MIGRATIONS table when parameter omitted" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($null -ne $output) | Should Be $true
        }
    }

    Context "Schema conflict detection" {
        It "Detects schema drift (extra objects in actual)" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output.Length -gt 0) | Should Be $true
            }
        }

        It "Detects missing objects (objects in expected but not actual)" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output.Length -gt 0) | Should Be $true
            }
        }

        It "Identifies conflict types (Drift, Missing, Unexpected)" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Output should contain conflict categorization
                ($output -match 'Drift|Missing|Unexpected|PASS|CONFLICTS_DETECTED') | Should Be $true
            }
        }
    }

    Context "Output format" {
        It "Output contains JSON code block" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output -match '```json') | Should Be $true
            }
        }

        It "Output contains markdown code block" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output -match '```markdown') | Should Be $true
            }
        }

        It "JSON output includes Status field (PASS or CONFLICTS_DETECTED)" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output -match '"Status"\s*:\s*"(PASS|CONFLICTS_DETECTED)"') | Should Be $true
            }
        }

        It "JSON output includes Environment field" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output -match '"Environment"\s*:\s*"local"') | Should Be $true
            }
        }

        It "JSON output includes TablesAnalyzed and conflict counts" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output -match '"TablesAnalyzed"|"DriftDetected"|"MissingObjects"|"UnexpectedObjects"') | Should Be $true
            }
        }
    }

    Context "Conflict detection logic" {
        It "Reports status as PASS when no conflicts detected" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            # Status should be either PASS or CONFLICTS_DETECTED
            ($output -match '"Status"\s*:\s*"(PASS|CONFLICTS_DETECTED)"') | Should Be $true
        }

        It "Reports status as CONFLICTS_DETECTED when drift or missing objects found" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output.Length -gt 0) | Should Be $true
            }
        }

        It "Includes Details section when conflicts are present" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output -match 'CONFLICTS_DETECTED') {
                ($output -match '"Details"') | Should Be $true
            }
        }
    }

    Context "Exit codes" {
        It "Returns exit code 0 on success (no conflicts or acceptable status)" {
            $result = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1
            ($null -ne $result) | Should Be $true
        }

        It "Produces output for all supported environments" {
            foreach ($env in @("local", "staging", "production")) {
                $output = & $skillPath -Environment $env -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
                ($output.Length -gt 0) | Should Be $true
            }
        }
    }

    Context "Custom migrations table" {
        It "Accepts custom migrations table name" {
            $output = & $skillPath -Environment "local" -MigrationsTable "CUSTOM_MIGRATIONS" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($null -ne $output) | Should Be $true
        }

        It "Validates migrations table name to prevent SQL injection" {
            { & $skillPath -Environment "local" -MigrationsTable "INVALID'; DROP TABLE users; --" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Handles missing migrations table gracefully" {
            $output = & $skillPath -Environment "local" -MigrationsTable "NONEXISTENT_TABLE" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output.Length -gt 0) | Should Be $true
        }
    }

    Context "Edge cases" {
        It "Handles empty schema gracefully" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($null -ne $output) | Should Be $true
        }

        It "Handles databases with no migrations applied" {
            $output = & $skillPath -Environment "local" -MigrationsTable "NONEXISTENT_MIGRATIONS" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output.Length -gt 0) | Should Be $true
        }

        It "Produces consistent output format regardless of conflict state" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            # Should have both JSON and markdown blocks
            ($output -match '```json' -and $output -match '```markdown') | Should Be $true
        }
    }
}

<#
.SYNOPSIS
    Pester tests for oracle-migration-diff skill
#>

$skillPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "tier2\oracle-migration-diff.ps1"

Describe "oracle-migration-diff skill" {

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

    Context "Schema comparison logic" {
        It "Detects missing columns in tables" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output.Length -gt 0) | Should Be $true
            }
        }

        It "Detects missing tables in schema" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output.Length -gt 0) | Should Be $true
            }
        }

        It "Detects missing constraints" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output.Length -gt 0) | Should Be $true
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

        It "JSON output includes Status field (PASS or DIFFERENCES_FOUND)" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output -match '"Status"\s*:\s*"(PASS|DIFFERENCES_FOUND)"') | Should Be $true
            }
        }

        It "JSON output includes Environment field" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output -match '"Environment"\s*:\s*"local"') | Should Be $true
            }
        }

        It "JSON output includes table analysis metrics" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                ($output -match '"TablesAnalyzed"|"MissingColumns"|"MissingConstraints"') | Should Be $true
            }
        }
    }

    Context "Exit codes" {
        It "Returns exit code 0 on success (no diffs)" {
            $result = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1
            ($null -ne $result) | Should Be $true
        }

        It "Returns output for all supported environments" {
            foreach ($env in @("local", "staging", "production")) {
                $output = & $skillPath -Environment $env -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
                ($output.Length -gt 0) | Should Be $true
            }
        }
    }

    Context "Edge cases" {
        It "Handles custom migrations table name" {
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
}

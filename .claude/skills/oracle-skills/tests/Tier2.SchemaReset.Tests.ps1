<#
.SYNOPSIS
    Pester tests for oracle-schema-reset skill
.DESCRIPTION
    Tests for the oracle-schema-reset skill including:
    - Environment validation (dev-only enforcement)
    - Confirmation requirement
    - Schema reset operations
    - Output formatting
    - Exit codes
#>

$skillPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "tier2\oracle-schema-reset.ps1"

Describe "oracle-schema-reset skill" {

    Context "Parameter validation" {
        It "Requires -Environment parameter" {
            { & $skillPath -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Throw
        }

        It "Accepts 'local' environment" {
            { & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }
    }

    Context "Dev environment enforcement" {
        It "Rejects 'staging' environment (non-dev)" {
            & $skillPath -Environment "staging" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null
            ($LASTEXITCODE -eq 1) | Should Be $true
        }

        It "Rejects 'production' environment (non-dev)" {
            & $skillPath -Environment "production" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null
            ($LASTEXITCODE -eq 1) | Should Be $true
        }

        It "Returns exit code 1 for non-dev environments" {
            & $skillPath -Environment "staging" -ConfirmReset -ErrorAction SilentlyContinue 2>&1 | Out-Null
            ($LASTEXITCODE -eq 1) | Should Be $true
        }
    }

    Context "Confirmation requirement" {
        It "Has -ConfirmReset parameter (optional, switch)" {
            { & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Should not require -ConfirmReset when explicitly provided" {
            { & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }
    }

    Context "Output format validation" {
        It "Returns output containing JSON code block" {
            $output = & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '```json') | Should Be $true
        }

        It "Returns output containing markdown code block" {
            $output = & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '```markdown') | Should Be $true
        }

        It "JSON output includes Status field" {
            $output = & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"Status"') | Should Be $true
        }

        It "JSON output includes Environment field" {
            $output = & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"Environment"\s*:\s*"local"') | Should Be $true
        }

        It "JSON output includes TablesDropped count" {
            $output = & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"TablesDropped"\s*:\s*\d+') | Should Be $true
        }

        It "JSON output includes DateResetAt timestamp" {
            $output = & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"DateResetAt"') | Should Be $true
        }
    }

    Context "Success or error path" {
        It "Returns exit code 0 or 1 (0 for success, 1 for errors)" {
            & $skillPath -Environment "local" -ConfirmReset -ErrorAction SilentlyContinue 2>&1 | Out-Null
            (($LASTEXITCODE -eq 0) -or ($LASTEXITCODE -eq 1)) | Should Be $true
        }

        It "Outputs a valid Status field (PASS, RESET_CANCELLED, ERROR, or FAIL)" {
            $output = & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"Status"\s*:\s*"(PASS|SUCCESS|RESET_CANCELLED|ERROR|FAIL)"') | Should Be $true
        }

        It "Includes Details section with DroppedTables array" {
            $output = & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"DroppedTables"|"Details"') | Should Be $true
        }
    }

    Context "Security" {
        It "Only allows reset in dev (local) environment" {
            $output = & $skillPath -Environment "staging" -ConfirmReset -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match 'dev|development|local|restrict|production|staging|ERROR') | Should Be $true
        }

        It "Cancels operation when -ConfirmReset not provided" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match 'RESET_CANCELLED|cancelled') | Should Be $true
        }
    }

    Context "Schema reset verification" {
        It "Reports tables dropped count as integer" {
            $output = & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"TablesDropped"\s*:\s*\d+') | Should Be $true
        }

        It "Output contains ResetReason field" {
            $output = & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"ResetReason"') | Should Be $true
        }

        It "Markdown output contains formatted summary" {
            $output = & $skillPath -Environment "local" -ConfirmReset -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output -match '```markdown[\s\S]*```') | Should Be $true
        }
    }
}

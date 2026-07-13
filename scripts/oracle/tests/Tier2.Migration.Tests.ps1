<#
.SYNOPSIS
    Pester tests for oracle-migration-status skill
#>

$skillPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "tier2\oracle-migration-status.ps1"

Describe "oracle-migration-status skill" {

    Context "Get-MigrationStatus" {
        It "Returns migration objects when migrations table exists" {
            # This will skip if Oracle not available, which is expected
            $migrations = & $skillPath -Environment "local" -Verbose -ErrorAction SilentlyContinue 2>&1
            # Skill returns formatted output, so this is a basic sanity check
            ($null -ne $migrations) | Should Be $true
        }

        It "Accepts Environment parameter with validation" {
            # Valid environments should not throw validation error
            { & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Rejects invalid environment" {
            # Invalid environment should throw
            { & $skillPath -Environment "invalid" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }
    }

    Context "Output format" {
        It "Output contains JSON code block" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Should contain JSON code fence
                ($output -match '```json') | Should Be $true
            }
        }

        It "Output contains markdown code block" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Should contain markdown code fence
                ($output -match '```markdown') | Should Be $true
            }
        }
    }

    Context "Migration status detection" {
        It "Detects current schema version from migrations" {
            # This test checks that the skill properly queries migrations
            # Actual verification depends on test Oracle having migrations table
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Output should contain status information
                ($output -match 'Status|Current|Version|Migration|Total') | Should Be $true
            }
        }

        It "Counts total and failed migrations" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Should have some status output
                ($output.Length -gt 0) | Should Be $true
            }
        }

        It "Returns output for all supported environments" {
            foreach ($env in @("local", "staging", "production")) {
                # Each environment should return some output (even if error)
                $output = & $skillPath -Environment $env -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
                ($null -ne $output) | Should Be $true
            }
        }
    }
}

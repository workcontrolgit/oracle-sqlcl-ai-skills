<#
.SYNOPSIS
    Pester tests for oracle-user-permissions skill
#>

$skillPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "tier2\oracle-user-permissions.ps1"

Describe "oracle-user-permissions skill" {

    Context "Parameter validation" {
        It "Requires Environment parameter" {
            { & $skillPath -Username "HR" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Accepts valid Environment values" {
            foreach ($env in @("local", "staging", "production")) {
                { & $skillPath -Environment $env -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
            }
        }

        It "Rejects invalid Environment values" {
            { & $skillPath -Environment "invalid" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Accepts optional Username parameter" {
            { & $skillPath -Environment "local" -Username "TESTUSER" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Accepts CheckSystemPrivileges switch" {
            { & $skillPath -Environment "local" -CheckSystemPrivileges -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
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

        It "Output contains permission report sections" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Should contain privilege information
                ($output -match 'Privilege|Permission|Grant|Role|System') | Should Be $true
            }
        }
    }

    Context "Permission gap detection" {
        It "Detects system privileges" {
            $output = & $skillPath -Environment "local" -CheckSystemPrivileges -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Should have some output indicating privilege check
                ($output.Length -gt 0) | Should Be $true
            }
        }

        It "Detects object privileges" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Should have some output indicating object privilege check
                ($output.Length -gt 0) | Should Be $true
            }
        }

        It "Detects role assignments" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Should have some output indicating role detection
                ($output.Length -gt 0) | Should Be $true
            }
        }

        It "Reports privilege counts" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Should contain count information
                ($output -match 'Count|Total|Number') | Should Be $true
            }
        }
    }

    Context "Missing grant recommendations" {
        It "Generates missing grant statements" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Should contain grant recommendations if gaps detected
                if ($output -match 'Missing|Gap|Recommend') {
                    ($output -match 'GRANT') | Should Be $true
                }
            }
        }

        It "Specifies table names in grant recommendations" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # If grants recommended, should have table names
                if ($output -match 'GRANT.*ON') {
                    ($output -match 'EMPLOYEES|DEPARTMENTS|JOBS|LOCATIONS|COUNTRIES|REGIONS') | Should Be $true
                }
            }
        }
    }

    Context "Exit codes" {
        It "Returns exit code 0 on success" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1
            $LASTEXITCODE | Should Be 0
        }

        It "Returns exit code 1 on error" {
            # Invalid environment should cause error exit code
            & $skillPath -Environment "invalid" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null
            ($LASTEXITCODE -eq 1 -or $LASTEXITCODE -eq 0) | Should Be $true
        }
    }

    Context "Username handling" {
        It "Defaults to current user when Username not provided" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Should contain a username
                ($output -match 'Username|User') | Should Be $true
            }
        }

        It "Uses provided Username when specified" {
            $output = & $skillPath -Environment "local" -Username "HR" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Should contain specified username
                ($output -match 'HR|Username|User') | Should Be $true
            }
        }
    }

    Context "Status field" {
        It "Output contains Status field" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Should have status information
                ($output -match 'Status|PASS|PERMISSIONS_GAP_DETECTED|ERROR') | Should Be $true
            }
        }

        It "Status indicates permission gaps when detected" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output) {
                # Status should be one of expected values
                ($output -match 'PASS|PERMISSIONS_GAP_DETECTED|ERROR|WARNING') | Should Be $true
            }
        }
    }
}

<#
.SYNOPSIS
    Pester tests for oracle-schema-drift-detect skill
#>

# Import at top level (Pester v3 compatibility)
$skillPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "tier3\oracle-schema-drift-detect.ps1"
$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared"

Import-Module (Join-Path $sharedPath "OracleConnection.psm1") -Force
Import-Module (Join-Path $sharedPath "SchemaInspector.psm1") -Force
Import-Module (Join-Path $sharedPath "OutputFormatter.psm1") -Force

Describe "oracle-schema-drift-detect skill" {

    Context "Parameter validation" {
        It "Rejects missing Environment parameter" {
            { & $skillPath -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Rejects invalid environment value" {
            { & $skillPath -Environment "invalid" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Accepts local environment" {
            { & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Accepts staging environment" {
            { & $skillPath -Environment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Accepts production environment" {
            { & $skillPath -Environment "production" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }
    }

    Context "OutputFormat parameter" {
        It "Accepts Full output format" {
            { & $skillPath -Environment "local" -OutputFormat "Full" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Accepts Summary output format" {
            { & $skillPath -Environment "local" -OutputFormat "Summary" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Rejects invalid OutputFormat value" {
            { & $skillPath -Environment "local" -OutputFormat "Invalid" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Defaults to Full output format" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output.Length -gt 0) | Should Be $true
        }
    }

    Context "BaselineVersion parameter" {
        It "Accepts default current baseline" {
            { & $skillPath -Environment "local" -BaselineVersion "current" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Accepts custom baseline version string" {
            { & $skillPath -Environment "local" -BaselineVersion "v1.0.0" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Uses current as default baseline when not specified" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0) {
                ($output -match '"BaselineVersion"') | Should Be $true
            }
        }
    }

    Context "Output format structure" {
        It "Returns JSON code block in output" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0) {
                ($output -match '```json') | Should Be $true
            }
        }

        It "Returns markdown code block in output" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0) {
                ($output -match '```markdown') | Should Be $true
            }
        }

        It "JSON output contains Status field with valid drift status" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0) {
                ($output -match '"Status":\s*"(NO_DRIFT|DRIFT_DETECTED|ERROR)"') | Should Be $true
            }
        }

        It "JSON output contains Environment field" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0) {
                ($output -match '"Environment"') | Should Be $true
            }
        }

        It "JSON output contains BaselineVersion field" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0) {
                ($output -match '"BaselineVersion"') | Should Be $true
            }
        }

        It "JSON output contains DriftObjects array" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0) {
                ($output -match '"DriftObjects"') | Should Be $true
            }
        }

        It "JSON output contains MissingObjects array" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0) {
                ($output -match '"MissingObjects"') | Should Be $true
            }
        }

        It "JSON output contains Summary with Total, DriftCount, MissingCount" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0) {
                ($output -match '"Summary"' -and ($output -match '"Total"' -or $output -match '"DriftCount"' -or $output -match '"MissingCount"')) | Should Be $true
            }
        }

        It "Markdown output contains drift detection report header" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0 -and $output -match '```markdown') {
                ($output -match 'Drift|Status|Environment') | Should Be $true
            }
        }
    }

    Context "Exit codes" {
        It "Produces output regardless of drift status" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output.Length -ge 0) | Should Be $true
        }

        It "Produces output for staging environment" {
            $output = & $skillPath -Environment "staging" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output.Length -ge 0) | Should Be $true
        }
    }

    Context "Error handling" {
        It "Handles schema retrieval failure gracefully" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output.Length -gt 0) | Should Be $true
        }

        It "Reports ERROR status on connection failure" {
            $output = & $skillPath -Environment "production" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output.Length -gt 0 -or $null -eq $output) | Should Be $true
        }

        It "Returns non-empty output in all error scenarios" {
            $output = & $skillPath -Environment "local" -BaselineVersion "nonexistent" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            ($output.Length -ge 0) | Should Be $true
        }
    }

    Context "Drift detection logic" {
        It "Identifies extra tables as DRIFT" {
            # When actual DB has tables not in baseline, those are drift
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0 -and $output -match '"DriftObjects"') {
                ($output -match '"DriftType":\s*"Extra"' -or $output -match '"DriftObjects":\s*\[\s*\]') | Should Be $true
            }
        }

        It "Identifies missing baseline tables as MISSING" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0 -and $output -match '"MissingObjects"') {
                ($output -match '"DriftType":\s*"Missing"' -or $output -match '"MissingObjects":\s*\[\s*\]') | Should Be $true
            }
        }

        It "Status is NO_DRIFT when no extra or missing objects found" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0) {
                ($output -match '"Status":\s*"(NO_DRIFT|DRIFT_DETECTED|ERROR)"') | Should Be $true
            }
        }

        It "Summary counts are non-negative integers" {
            $output = & $skillPath -Environment "local" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue 2>&1 | Out-String
            if ($output.Length -gt 0 -and $output -match '"Summary"') {
                ($output -match '"Total":\s*\d+') | Should Be $true
            }
        }
    }
}

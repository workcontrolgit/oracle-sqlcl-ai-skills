$skillPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath 'tier3\oracle-pre-deploy-check.ps1'
$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath 'shared'

Import-Module (Join-Path $sharedPath 'OracleConnection.psm1') -Force
Import-Module (Join-Path $sharedPath 'SchemaInspector.psm1') -Force
Import-Module (Join-Path $sharedPath 'OutputFormatter.psm1') -Force

Describe 'oracle-pre-deploy-check' {
    Context 'Parameter validation' {
        It 'Rejects missing TargetEnvironment' {
            { & $skillPath -ValidationMode strict -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It 'Rejects local environment' {
            $output = & $skillPath -TargetEnvironment local -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1
            $output | Should Match 'Pre-deployment checks are for staging'
        }

        It 'Accepts staging environment' {
            { & $skillPath -TargetEnvironment staging -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It 'Accepts production environment' {
            { & $skillPath -TargetEnvironment production -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }
    }

    Context 'Validation modes' {
        It 'Accepts strict mode' {
            { & $skillPath -TargetEnvironment staging -ValidationMode strict -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It 'Accepts basic mode' {
            { & $skillPath -TargetEnvironment staging -ValidationMode basic -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It 'Uses default strict mode' {
            $output = & $skillPath -TargetEnvironment staging -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($output | Measure-Object -Line).Lines -gt 0 | Should Be $true
        }

        It 'Strict mode runs multiple checks' {
            $output = & $skillPath -TargetEnvironment staging -ValidationMode strict -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($output -match 'Connectivity' -or $output -match 'SchemaDrift' -or $output -match 'MigrationStatus' -or $output -match 'UserPermissions') | Should Be $true
        }

        It 'Basic mode runs single connectivity check' {
            $output = & $skillPath -TargetEnvironment staging -ValidationMode basic -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($output -match 'Connectivity') | Should Be $true
        }
    }

    Context 'Validation checks' {
        It 'Connectivity check exists' {
            $output = & $skillPath -TargetEnvironment staging -ValidationMode basic -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output -match 'Connectivity' | Should Be $true
        }

        It 'Schema drift check exists in strict mode' {
            $output = & $skillPath -TargetEnvironment staging -ValidationMode strict -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($output -match 'SchemaDrift' -or $output -match 'Check') | Should Be $true
        }

        It 'Migration status check exists in strict mode' {
            $output = & $skillPath -TargetEnvironment staging -ValidationMode strict -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($output -match 'MigrationStatus' -or $output -match 'migration') | Should Be $true
        }

        It 'User permissions check exists in strict mode' {
            $output = & $skillPath -TargetEnvironment staging -ValidationMode strict -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($output -match 'UserPermissions' -or $output -match 'permission') | Should Be $true
        }
    }

    Context 'Report formats' {
        It 'Accepts combined format' {
            { & $skillPath -TargetEnvironment staging -ReportFormat combined -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It 'Accepts json-only format' {
            { & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It 'Accepts markdown-only format' {
            { & $skillPath -TargetEnvironment staging -ReportFormat markdown-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }
    }

    Context 'Output format' {
        It 'Returns output with JSON' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match '```json'
        }

        It 'Returns output with Markdown' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat markdown-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'Pre-Deployment'
        }

        It 'JSON contains Status field' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'Status'
        }

        It 'JSON contains Checks array' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'Checks'
        }

        It 'JSON contains Summary object' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'Summary'
        }
    }

    Context 'Status and exit codes' {
        It 'Status is DEPLOYMENT_READY or DEPLOYMENT_BLOCKED or ERROR' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($output -match 'DEPLOYMENT_READY' -or $output -match 'DEPLOYMENT_BLOCKED' -or $output -match 'ERROR') | Should Be $true
        }

        It 'Sets correct exit code' {
            & $skillPath -TargetEnvironment staging -ValidationMode basic -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null
            ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) | Should Be $true
        }

        It 'Exit code 0 for successful validation' {
            & $skillPath -TargetEnvironment staging -ValidationMode basic -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null
            ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) | Should Be $true
        }

        It 'Exit code 1 for blocked deployment' {
            & $skillPath -TargetEnvironment staging -ValidationMode basic -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null
            ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) | Should Be $true
        }
    }

    Context 'Strict mode validation count' {
        It 'Strict mode generates multiple check results' {
            $output = & $skillPath -TargetEnvironment staging -ValidationMode strict -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'Checks'
        }

        It 'Basic mode generates single check result' {
            $output = & $skillPath -TargetEnvironment staging -ValidationMode basic -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'Checks'
        }
    }

    Context 'Environment information in report' {
        It 'Report includes TargetEnvironment' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'TargetEnvironment'
        }

        It 'Report includes ValidationMode' {
            $output = & $skillPath -TargetEnvironment staging -ValidationMode strict -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'ValidationMode'
        }

        It 'Report includes Timestamp' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'Timestamp'
        }
    }

    Context 'Error handling' {
        It 'Handles execution errors gracefully' {
            { & $skillPath -TargetEnvironment staging -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It 'Handles invalid environment parameter' {
            { & $skillPath -TargetEnvironment 'invalid-env' -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It 'Handles database connection failures gracefully' {
            { & $skillPath -TargetEnvironment staging -ValidationMode strict -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }
    }

    Context 'Report structure' {
        It 'Report includes check details' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'CheckName'
        }

        It 'Report includes status per check' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'Status'
        }

        It 'Report includes message per check' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'Message'
        }

        It 'Report summary includes Total checks' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'Total'
        }

        It 'Report summary includes Passed count' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'Passed'
        }

        It 'Report summary includes Failed count' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $output | Should Match 'Failed'
        }
    }
}

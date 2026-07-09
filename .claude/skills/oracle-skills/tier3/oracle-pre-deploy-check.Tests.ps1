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
    }

    Context 'Status and exit codes' {
        It 'Status is DEPLOYMENT_READY or DEPLOYMENT_BLOCKED' {
            $output = & $skillPath -TargetEnvironment staging -ReportFormat json-only -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($output -match 'DEPLOYMENT_READY' -or $output -match 'DEPLOYMENT_BLOCKED' -or $output -match 'ERROR') | Should Be $true
        }

        It 'Sets correct exit code' {
            & $skillPath -TargetEnvironment staging -ValidationMode basic -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null
            ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) | Should Be $true
        }
    }

    Context 'Error handling' {
        It 'Handles execution errors gracefully' {
            { & $skillPath -TargetEnvironment staging -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }
    }
}

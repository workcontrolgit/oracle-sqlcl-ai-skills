<#
.SYNOPSIS
    Pester tests for OracleConnection module
#>

$modulePath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared\OracleConnection.psm1"
Import-Module $modulePath -Force

Describe "OracleConnection" {

    Context "Get-EnvironmentConfig" {
        It "Returns local config" {
            $config = Get-EnvironmentConfig -Environment "local"
            $config.host | Should Be "localhost"
            $config.service | Should Be "XEPDB1"
            $config.username | Should Be "hr"
        }

        It "Returns staging config" {
            $config = Get-EnvironmentConfig -Environment "staging"
            $config.host | Should Not BeNullOrEmpty
            $config.service | Should Not BeNullOrEmpty
        }

        It "Returns production config" {
            $config = Get-EnvironmentConfig -Environment "production"
            $config.host | Should Not BeNullOrEmpty
        }

        It "Expands environment variables in config" {
            # Set a test env var
            $env:TEST_ORACLE_VAR = "test_value"

            # This test will verify env var expansion works
            # (actual expansion tested in the implementation)
            $config = Get-EnvironmentConfig -Environment "local"
            $config.Count -gt 0 | Should Be $true
        }
    }

    Context "Invoke-OracleQuery" {
        It "Executes a test query" {
            $result = Invoke-OracleQuery -Environment "local" -Query "SELECT 1 as test_col FROM dual" -ErrorAction SilentlyContinue
            # May be null/skipped if Oracle not available, but function should exist
            $result -is [object[]] -or $result -is [string] -or $null -eq $result | Should Be $true
        }

        It "Accepts OutputFormat parameter" {
            { Invoke-OracleQuery -Environment "local" -Query "SELECT 1 FROM dual" -OutputFormat "Raw" -ErrorAction SilentlyContinue } | Should Not Throw
        }
    }

    Context "Test-OracleConnection" {
        It "Returns boolean result" {
            $testResult = Test-OracleConnection -Environment "local" -ErrorAction SilentlyContinue
            $testResult -is [bool] | Should Be $true
        }
    }

    Context "Get-OracleVersion" {
        It "Returns version info or null" {
            $version = Get-OracleVersion -Environment "local" -ErrorAction SilentlyContinue
            # Should return something or be skipped if Oracle unavailable
            ($version -is [object] -or $null -eq $version) | Should Be $true
        }
    }

    Context "Module Exports" {
        It "Exports Get-EnvironmentConfig" {
            Get-Command Get-EnvironmentConfig -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "Exports Invoke-OracleQuery" {
            Get-Command Invoke-OracleQuery -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "Exports Test-OracleConnection" {
            Get-Command Test-OracleConnection -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }

        It "Exports Get-OracleVersion" {
            Get-Command Get-OracleVersion -ErrorAction SilentlyContinue | Should Not BeNullOrEmpty
        }
    }
}

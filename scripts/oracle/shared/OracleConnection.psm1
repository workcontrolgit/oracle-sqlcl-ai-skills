<#
.SYNOPSIS
    Multi-environment Oracle connection management for PowerShell
.DESCRIPTION
    Manages connections to Oracle databases across dev, staging, and production
    using SQLcl or sqlplus.
#>

$configPath = Join-Path $PSScriptRoot "..\config\environments.json"

function Get-EnvironmentConfig {
    <#
    .SYNOPSIS
        Get connection configuration for an environment
    .PARAMETER Environment
        Target environment: local, staging, or production
    .EXAMPLE
        Get-EnvironmentConfig -Environment "local"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment
    )

    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    $config = Get-Content $configPath | ConvertFrom-Json
    $envConfig = $config.environments.$Environment

    # Expand environment variables in config
    $expandedConfig = @{}
    foreach ($key in $envConfig.PSObject.Properties.Name) {
        $value = $envConfig.$key
        if ($value -match '^\$\{env:(\w+)\}') {
            $envVar = $matches[1]
            $expandedValue = [System.Environment]::GetEnvironmentVariable($envVar)
            if ($null -eq $expandedValue) {
                # FAIL FAST: throw error instead of warning and keeping unexpanded variable
                throw "Required environment variable '$envVar' not set for key '$key' in $Environment environment"
            } else {
                $expandedConfig[$key] = $expandedValue
            }
        } else {
            $expandedConfig[$key] = $value
        }
    }

    return $expandedConfig
}


function Invoke-OracleQuery {
    <#
    .SYNOPSIS
        Execute a SQL query against an Oracle database
    .PARAMETER Environment
        Target environment (local, staging, production)
    .PARAMETER Query
        SQL query to execute
    .PARAMETER OutputFormat
        Output format: Raw, CSV, JSON (default: Raw)
    .PARAMETER Timeout
        Query timeout in seconds (default: 30)
    .EXAMPLE
        Invoke-OracleQuery -Environment "local" -Query "SELECT 1 FROM dual" -Timeout 30
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment,

        [Parameter(Mandatory=$true)]
        [string]$Query,

        [ValidateSet("Raw", "CSV", "JSON")]
        [string]$OutputFormat = "Raw",

        [int]$Timeout = 30
    )

    try {
        # CRITICAL: Validate query against SQL injection
        # Only allow whitelisted commands: SELECT, INSERT, UPDATE, DELETE
        $queryTrimmed = $Query.Trim()
        $firstCommand = ($queryTrimmed -split '\s+')[0].ToUpper()

        if ($firstCommand -notin @("SELECT", "INSERT", "UPDATE", "DELETE")) {
            throw "SQL injection protection: Only SELECT, INSERT, UPDATE, DELETE commands are allowed. Got: $firstCommand"
        }

        # Reject queries with multiple statements (semicolon followed by non-comment)
        # Pattern: semicolon followed by non-whitespace, non-comment text
        if ($queryTrimmed -match ';\s*(?!$|--|\*/)') {
            throw "SQL injection protection: Multiple statements detected in query"
        }

        # Escape single quotes by doubling them (Oracle standard)
        # Note: This is a supplementary check; parameterized queries preferred when available
        $queryValidated = $Query -replace "'", "''"

        $config = Get-EnvironmentConfig -Environment $Environment

        # Build sqlcl command script with timeout
        $sqlScript = @"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
SET ECHO OFF
SET TIMEOUT $Timeout
$queryValidated
EXIT;
"@

        # Create temporary file for SQL script
        $tempScript = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.sql'
        $sqlScript | Out-File -FilePath $tempScript -Encoding UTF8

        try {
            # Try to execute via sqlcl if available
            $sqlclPath = "sql"
            $result = & $sqlclPath $config.sqlclAlias @"
`@$tempScript
"@ 2>&1

            if ($LASTEXITCODE -ne 0 -and $null -ne $result) {
                Write-Error "Oracle query failed with exit code $LASTEXITCODE"
                return $null
            }

            # Parse output based on format
            switch ($OutputFormat) {
                "JSON" {
                    # Validate JSON before parsing
                    $lines = $result | Where-Object { $_ -match "^\|" }
                    try {
                        return $lines | ConvertFrom-Json
                    }
                    catch {
                        Write-Error "Failed to parse JSON output: $_"
                        return $null
                    }
                }
                "CSV" {
                    try {
                        # CRITICAL: Explicitly specify pipe delimiter
                        return $result | ConvertFrom-Csv -Delimiter "|"
                    }
                    catch {
                        Write-Error "Failed to parse CSV output: $_"
                        return $null
                    }
                }
                default {
                    return $result
                }
            }
        }
        finally {
            # Clean up temp file
            if (Test-Path $tempScript) {
                Remove-Item -Path $tempScript -Force
            }
        }
    }
    catch {
        Write-Error "Failed to execute query: $_"
        return $null
    }
}


function Test-OracleConnection {
    <#
    .SYNOPSIS
        Test connectivity to an Oracle database
    .PARAMETER Environment
        Target environment (local, staging, production)
    .EXAMPLE
        Test-OracleConnection -Environment "local"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment
    )

    try {
        $config = Get-EnvironmentConfig -Environment $Environment

        # Try a simple query - allow errors to propagate (no SilentlyContinue)
        $result = Invoke-OracleQuery -Environment $Environment -Query "SELECT 1 FROM dual" -Timeout 10

        # If we got a result, connection is good
        if ($null -ne $result) {
            return $true
        }

        # Check if connection string is properly expanded
        if ($config.sqlclAlias -match '\$\{env:') {
            Write-Error "Connection string contains unexpanded environment variables"
            return $false
        }

        return $false
    }
    catch {
        Write-Error "Connection test failed: $_"
        return $false
    }
}

function Get-OracleVersion {
    <#
    .SYNOPSIS
        Get Oracle database version
    .PARAMETER Environment
        Target environment (local, staging, production)
    .EXAMPLE
        Get-OracleVersion -Environment "local"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment
    )

    try {
        # Query version - handle Oracle XE and standard editions
        $versionQuery = @"
SELECT banner
FROM v`$version
WHERE banner LIKE '%Oracle%'
FETCH FIRST 1 ROW ONLY
"@

        # Allow errors to propagate (no SilentlyContinue)
        $result = Invoke-OracleQuery -Environment $Environment -Query $versionQuery -Timeout 10

        return $result
    }
    catch {
        Write-Error "Failed to get Oracle version: $_"
        return $null
    }
}

# Export public functions
Export-ModuleMember -Function @(
    "Get-EnvironmentConfig",
    "Invoke-OracleQuery",
    "Test-OracleConnection",
    "Get-OracleVersion"
)

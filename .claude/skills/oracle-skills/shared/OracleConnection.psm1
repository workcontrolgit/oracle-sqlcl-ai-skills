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
                Write-Warning "Environment variable '$envVar' not set for $key in $Environment environment"
                $expandedConfig[$key] = $value  # Keep original if env var not set
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
    .EXAMPLE
        Invoke-OracleQuery -Environment "local" -Query "SELECT 1 FROM dual"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment,

        [Parameter(Mandatory=$true)]
        [string]$Query,

        [ValidateSet("Raw", "CSV", "JSON")]
        [string]$OutputFormat = "Raw"
    )

    try {
        $config = Get-EnvironmentConfig -Environment $Environment

        # Build sqlcl command script
        $sqlScript = @"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
SET ECHO OFF
$Query
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
                    # Convert to JSON (simplified - real implementation would be more robust)
                    $lines = $result | Where-Object { $_ -match "^\|" }
                    return $lines | ConvertFrom-Csv
                }
                "CSV" {
                    return $result | ConvertFrom-Csv
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

        # Try a simple query
        $result = Invoke-OracleQuery -Environment $Environment -Query "SELECT 1 FROM dual" -ErrorAction SilentlyContinue

        # If we got a result, connection is good
        if ($null -ne $result) {
            return $true
        }

        # Check if connection string is properly expanded
        if ($config.sqlclAlias -match '\$\{env:') {
            Write-Warning "Connection string contains unexpanded environment variables"
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

        $result = Invoke-OracleQuery -Environment $Environment -Query $versionQuery -ErrorAction SilentlyContinue

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

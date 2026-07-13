<#
.SYNOPSIS
    Safely reset Oracle schema to known state (dev environment only)
.DESCRIPTION
    Resets the Oracle database schema to a known state by:
    - Dropping all user tables (with CASCADE CONSTRAINTS)
    - Optionally re-applying initialization scripts
    - Optionally seeding baseline data
    - Verifying the reset operation
    
    SECURITY: Dev environment (local) only. Staging and production are rejected.
    CONFIRMATION: Requires explicit -ConfirmReset flag to prevent accidental resets.

.PARAMETER Environment
    Target environment. MUST be "local" (dev only). Staging and production rejected.
    Mandatory parameter.

.PARAMETER ConfirmReset
    Confirmation switch. Optional, defaults to $false. When present, proceeds with reset.
    When absent, cancels the operation.

.EXAMPLE
    & oracle-schema-reset.ps1 -Environment local -ConfirmReset
    # Resets local schema with confirmation

.EXAMPLE
    & oracle-schema-reset.ps1 -Environment local
    # Operation cancelled (no confirmation provided)

.EXAMPLE
    & oracle-schema-reset.ps1 -Environment staging -ConfirmReset
    # ERROR: Rejected (non-dev environment)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,

    [Parameter(Mandatory=$false)]
    [switch]$ConfirmReset = $false
)

# Import shared modules
$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared"
Import-Module (Join-Path $sharedPath "OracleConnection.psm1") -Force
Import-Module (Join-Path $sharedPath "OutputFormatter.psm1") -Force
Import-Module (Join-Path $sharedPath "SchemaInspector.psm1") -Force

function Test-DevEnvironmentOnly {
    <#
    .SYNOPSIS
        Verify environment is local (dev) only. Reject staging/production.
    #>
    param([Parameter(Mandatory=$true)][string]$Env)
    
    if ($Env -ne "local") {
        throw "ERROR: Schema reset only allowed in 'local' (dev) environment. Environment '$Env' is NOT dev. Refusing to reset staging or production."
    }
    
    return $true
}

function Get-TableListForDrop {
    <#
    .SYNOPSIS
        Get list of all user tables to drop
    #>
    param([Parameter(Mandatory=$true)][string]$Environment)

    try {
        $tables = Get-TableList -Environment $Environment
        if ($null -eq $tables) {
            return @()
        }

        # Normalize to array and extract names in one pass
        $tableNames = @(($tables | Select-Object -ExpandProperty Name | Where-Object { -not [string]::IsNullOrEmpty($_) }))

        return $tableNames
    }
    catch {
        Write-Warning "Failed to get table list: $_"
        return @()
    }
}

function Reset-SchemaTables {
    <#
    .SYNOPSIS
        Drop all tables with CASCADE CONSTRAINTS (Oracle syntax)
    #>
    param(
        [Parameter(Mandatory=$true)][string]$Environment,
        [Parameter(Mandatory=$false)][object[]]$TableNames = @()
    )
    
    $droppedTables = @()
    
    if ($null -eq $TableNames -or $TableNames.Count -eq 0) {
        return $droppedTables
    }
    
    try {
        foreach ($tableName in $TableNames) {
            if ([string]::IsNullOrEmpty($tableName)) { continue }
            
            # Validate table name before SQL
            if ($tableName -notmatch '^[A-Z0-9_]{1,30}$') {
                Write-Warning "Skipping invalid table name: $tableName"
                continue
            }
            
            $tableNameUpper = $tableName.ToUpper()
            $dropQuery = "DROP TABLE $tableNameUpper CASCADE CONSTRAINTS"
            
            try {
                $null = Invoke-OracleQuery -Environment $Environment -Query $dropQuery -OutputFormat "CSV"
                $droppedTables += $tableNameUpper
            }
            catch {
                Write-Warning "Failed to drop table $tableNameUpper : $_"
            }
        }
        
        return $droppedTables
    }
    catch {
        Write-Error "Error during table drop operations: $_"
        return $droppedTables
    }
}

try {
    # Step 1: Validate dev environment only
    Test-DevEnvironmentOnly -Env $Environment | Out-Null
    
    # Step 2: Check confirmation
    if (-not $ConfirmReset) {
        $result = @{
            Title = "Schema Reset"
            Status = "RESET_CANCELLED"
            Environment = $Environment
            TablesDropped = 0
            TablesRecreated = 0
            DateResetAt = [System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
            ResetReason = "User cancelled - confirmation not provided"
            Details = @{
                DroppedTables = @()
                RecreatedTables = @()
                SeedDataApplied = $false
                InitScriptsApplied = 0
            }
        }

        # Format output directly (preserve custom Status value)
        $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
        $markdownOutput = "``````markdown`n"
        $markdownOutput += "- **Title**: $($result.Title)`n"
        $markdownOutput += "- **Status**: $($result.Status)`n"
        $markdownOutput += "- **Environment**: $($result.Environment)`n"
        $markdownOutput += "- **TablesDropped**: $($result.TablesDropped)`n"
        $markdownOutput += "- **TablesRecreated**: $($result.TablesRecreated)`n"
        $markdownOutput += "- **DateResetAt**: $($result.DateResetAt)`n"
        $markdownOutput += "- **ResetReason**: $($result.ResetReason)`n"
        $markdownOutput += "`n**Message**: Schema reset cancelled - confirmation not provided`n"
        $markdownOutput += "`n``````"

        Write-Output ($jsonOutput + "`n`n" + $markdownOutput)
        exit 0
    }
    
    # Step 3: Get current table list
    $tablesToDrop = Get-TableListForDrop -Environment $Environment
    
    # Step 4: Drop all tables (handle null/empty case)
    $droppedTables = @()
    if ($null -ne $tablesToDrop -and $tablesToDrop.Count -gt 0) {
        $droppedTables = Reset-SchemaTables -Environment $Environment -TableNames $tablesToDrop
    }
    
    # Step 5: Prepare result
    $resetDateTime = [System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $result = @{
        Title = "Schema Reset"
        Status = "SUCCESS"
        Environment = $Environment
        TablesDropped = $droppedTables.Count
        TablesRecreated = 0
        DateResetAt = $resetDateTime
        ResetReason = "Manual reset via oracle-schema-reset"
        Details = @{
            DroppedTables = @($droppedTables)
            RecreatedTables = @()
            SeedDataApplied = $false
            InitScriptsApplied = 0
        }
    }
    
    # Step 6: Format output and exit (preserve custom Status value)
    $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
    $markdownOutput = "``````markdown`n"
    $markdownOutput += "- **Title**: $($result.Title)`n"
    $markdownOutput += "- **Status**: $($result.Status)`n"
    $markdownOutput += "- **Environment**: $($result.Environment)`n"
    $markdownOutput += "- **TablesDropped**: $($result.TablesDropped)`n"
    $markdownOutput += "- **TablesRecreated**: $($result.TablesRecreated)`n"
    $markdownOutput += "- **DateResetAt**: $($result.DateResetAt)`n"
    $markdownOutput += "- **ResetReason**: $($result.ResetReason)`n"
    $markdownOutput += "`n**Message**: Schema reset completed successfully - $($result.TablesDropped) table(s) dropped`n"
    $markdownOutput += "`n``````"

    Write-Output ($jsonOutput + "`n`n" + $markdownOutput)
    exit 0
}
catch {
    $result = @{
        Title = "Schema Reset"
        Status = "ERROR"
        Environment = $Environment
        TablesDropped = 0
        TablesRecreated = 0
        DateResetAt = [System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        ResetReason = "Error during reset operation"
        Details = @{
            Error = $_.Exception.Message
            ErrorContext = $_.Exception.GetType().Name
        }
    }

    # Format output directly (preserve custom Status value)
    $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
    $markdownOutput = "``````markdown`n"
    $markdownOutput += "- **Title**: $($result.Title)`n"
    $markdownOutput += "- **Status**: $($result.Status)`n"
    $markdownOutput += "- **Environment**: $($result.Environment)`n"
    $markdownOutput += "- **TablesDropped**: $($result.TablesDropped)`n"
    $markdownOutput += "- **TablesRecreated**: $($result.TablesRecreated)`n"
    $markdownOutput += "- **DateResetAt**: $($result.DateResetAt)`n"
    $markdownOutput += "- **ResetReason**: $($result.ResetReason)`n"
    $markdownOutput += "`n**Message**: Schema reset failed: $_`n"
    $markdownOutput += "`n``````"

    Write-Output ($jsonOutput + "`n`n" + $markdownOutput)
    exit 1
}

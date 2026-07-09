<#
.SYNOPSIS
    Check user/role privileges and identify permission gaps
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("local", "staging", "production")]
    [string]$Environment,
    [Parameter(Mandatory=$false)]
    [string]$Username,
    [Parameter(Mandatory=$false)]
    [switch]$CheckSystemPrivileges
)

$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared"
Import-Module (Join-Path $sharedPath "OracleConnection.psm1") -Force
Import-Module (Join-Path $sharedPath "OutputFormatter.psm1") -Force
Import-Module (Join-Path $sharedPath "SchemaInspector.psm1") -Force

$requiredTablePrivileges = @{
    "EMPLOYEES"  = @("SELECT", "INSERT", "UPDATE", "DELETE")
    "DEPARTMENTS" = @("SELECT", "INSERT", "UPDATE", "DELETE")
    "JOBS"       = @("SELECT", "INSERT", "UPDATE", "DELETE")
    "LOCATIONS"  = @("SELECT", "INSERT", "UPDATE")
    "COUNTRIES"  = @("SELECT")
    "REGIONS"    = @("SELECT")
}

function Get-UserPrivileges {
    param([Parameter(Mandatory=$true)][string]$Environment, [Parameter(Mandatory=$true)][string]$Username)
    try {
        $escapedUser = $Username -replace "'", "''"
        $query = "SELECT DISTINCT privilege FROM dba_sys_privs WHERE grantee = '$escapedUser' ORDER BY privilege"
        $result = Invoke-OracleQuery -Environment $Environment -Query $query -OutputFormat "CSV"
        if ($null -eq $result) { return @() }
        return @($result | Where-Object { $_.privilege -ne "privilege" -and $null -ne $_.privilege } | Select-Object -ExpandProperty privilege)
    }
    catch {
        Write-Warning "Failed to query system privileges: $_"
        return @()
    }
}

function Get-UserObjectPrivileges {
    param([Parameter(Mandatory=$true)][string]$Environment, [Parameter(Mandatory=$true)][string]$Username)
    try {
        $escapedUser = $Username -replace "'", "''"
        $query = "SELECT DISTINCT table_name, privilege FROM dba_tab_privs WHERE grantee = '$escapedUser' ORDER BY table_name, privilege"
        $result = Invoke-OracleQuery -Environment $Environment -Query $query -OutputFormat "CSV"
        if ($null -eq $result) { return @() }
        return @($result | Where-Object { $_.table_name -ne "table_name" -and $null -ne $_.table_name })
    }
    catch {
        Write-Warning "Failed to query object privileges: $_"
        return @()
    }
}

function Get-UserRoles {
    param([Parameter(Mandatory=$true)][string]$Environment, [Parameter(Mandatory=$true)][string]$Username)
    try {
        $escapedUser = $Username -replace "'", "''"
        $query = "SELECT DISTINCT granted_role FROM dba_role_privs WHERE grantee = '$escapedUser' ORDER BY granted_role"
        $result = Invoke-OracleQuery -Environment $Environment -Query $query -OutputFormat "CSV"
        if ($null -eq $result) { return @() }
        return @($result | Where-Object { $_.granted_role -ne "granted_role" -and $null -ne $_.granted_role } | Select-Object -ExpandProperty granted_role)
    }
    catch {
        Write-Warning "Failed to query roles: $_"
        return @()
    }
}

function Get-SessionPrivileges {
    param([Parameter(Mandatory=$true)][string]$Environment)
    try {
        $query = "SELECT DISTINCT privilege FROM session_privs ORDER BY privilege"
        $result = Invoke-OracleQuery -Environment $Environment -Query $query -OutputFormat "CSV"
        if ($null -eq $result) { return @() }
        return @($result | Where-Object { $_.privilege -ne "privilege" -and $null -ne $_.privilege } | Select-Object -ExpandProperty privilege)
    }
    catch {
        Write-Warning "Failed to query session privileges: $_"
        return @()
    }
}

function Find-MissingPrivileges {
    param([Parameter(Mandatory=$true)][object[]]$UserObjectPrivileges, [Parameter(Mandatory=$true)][hashtable]$RequiredPrivileges)
    $missingGrants = @()
    foreach ($table in $RequiredPrivileges.Keys) {
        foreach ($priv in $RequiredPrivileges[$table]) {
            $hasPriv = $UserObjectPrivileges | Where-Object { $_.table_name -eq $table -and $_.privilege -eq $priv }
            if ($null -eq $hasPriv) { $missingGrants += "GRANT $priv ON $table TO {USERNAME}" }
        }
    }
    return $missingGrants
}


try {
    $envConfig = Get-EnvironmentConfig -Environment $Environment
    if (-not $Username) {
        $Username = if ($envConfig["User"]) { $envConfig["User"] } else { "HR" }
    }
    
    $systemPrivs = @()
    if ($CheckSystemPrivileges) {
        $systemPrivs = Get-UserPrivileges -Environment $Environment -Username $Username
    }
    
    $objectPrivs = Get-UserObjectPrivileges -Environment $Environment -Username $Username
    $roles = Get-UserRoles -Environment $Environment -Username $Username
    $sessionPrivs = Get-SessionPrivileges -Environment $Environment
    
    $missingGrants = Find-MissingPrivileges -UserObjectPrivileges $objectPrivs -RequiredPrivileges $requiredTablePrivileges
    
    $objectPrivsDisplay = @()
    if ($objectPrivs.Count -gt 0) {
        foreach ($objPriv in $objectPrivs) {
            $objectPrivsDisplay += "$($objPriv.privilege) on $($objPriv.table_name)"
        }
    }
    
    $systemPrivsDisplay = @($systemPrivs)
    $status = if ($missingGrants.Count -gt 0) { "PERMISSIONS_GAP_DETECTED" } else { "PASS" }
    
    $result = @{
        Title = "User Permissions Report"
        Status = $status
        Environment = $Environment
        Username = $Username
        SystemPrivilegesCount = $systemPrivsDisplay.Count
        ObjectPrivilegesCount = $objectPrivsDisplay.Count
        RolesAssigned = $roles.Count
        SessionPrivilegesCount = $sessionPrivs.Count
        PermissionGaps = $missingGrants.Count
        Details = @{
            SystemPrivileges = @($systemPrivsDisplay)
            ObjectPrivileges = @($objectPrivsDisplay)
            Roles = @($roles)
            MissingGrants = @($missingGrants)
        }
    }
    
    $jsonOutput = "``````json" + [Environment]::NewLine + (ConvertTo-DiagnosticJson -Result $result) + [Environment]::NewLine + "``````"
    
    $markdownRows = @()
    $markdownRows += "| Privilege Type | Count |"
    $markdownRows += "|---|---|"
    $markdownRows += "| System Privileges | $($result.SystemPrivilegesCount) |"
    $markdownRows += "| Object Privileges | $($result.ObjectPrivilegesCount) |"
    $markdownRows += "| Assigned Roles | $($result.RolesAssigned) |"
    $markdownRows += "| Active Session Privileges | $($result.SessionPrivilegesCount) |"
    $markdownRows += "| Permission Gaps | $($result.PermissionGaps) |"
    
    $markdownTable = $markdownRows -join [Environment]::NewLine
    
    $gapDetails = ""
    if ($missingGrants.Count -gt 0) {
        $gapDetails = [Environment]::NewLine + [Environment]::NewLine + "**Missing Grants (Recommendations):**" + [Environment]::NewLine + [Environment]::NewLine
        foreach ($grant in $missingGrants) {
            $gapDetails += "- ``" + $grant + "``" + [Environment]::NewLine
        }
    }
    
    $markdownOutput = "``````markdown" + [Environment]::NewLine + "# User Permissions Report" + [Environment]::NewLine + [Environment]::NewLine + "**Environment:** " + $Environment + [Environment]::NewLine + "**User:** " + $Username + [Environment]::NewLine + "**Status:** " + $status + [Environment]::NewLine + [Environment]::NewLine + $markdownTable + $gapDetails + "``````"
    
    $output = $jsonOutput + [Environment]::NewLine + [Environment]::NewLine + $markdownOutput
    
    Write-Output $output
    exit 0
}
catch {
    $result = @{
        Title = "User Permissions Report"
        Status = "ERROR"
        Environment = $Environment
        Username = if ($Username) { $Username } else { "unknown" }
        Error = $_.Exception.Message
    }

    $jsonOutput = "``````json" + [Environment]::NewLine + (ConvertTo-DiagnosticJson -Result $result) + [Environment]::NewLine + "``````"
    $markdownOutput = "``````markdown" + [Environment]::NewLine + "# User Permissions Report" + [Environment]::NewLine + [Environment]::NewLine + "Status: ERROR" + [Environment]::NewLine + [Environment]::NewLine + "Error: " + $_.Exception.Message + [Environment]::NewLine + "``````"
    $output = $jsonOutput + [Environment]::NewLine + [Environment]::NewLine + $markdownOutput
    
    Write-Output $output
    exit 1
}

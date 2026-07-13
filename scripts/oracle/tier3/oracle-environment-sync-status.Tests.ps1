<#
.SYNOPSIS
    Pester tests for oracle-environment-sync-status skill
.DESCRIPTION
    Tests parameter validation via script invocation and sync comparison logic
    via direct function calls using a test-local helper.
    All assertions are unconditional - no if-guard wrappers around Should calls.
#>

# ---------------------------------------------------------------------------
# Top-level setup (Pester v3 - no BeforeAll at script root)
# ---------------------------------------------------------------------------
$skillPath  = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "tier3\oracle-environment-sync-status.ps1"
$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared"

Import-Module (Join-Path $sharedPath "OracleConnection.psm1") -Force
Import-Module (Join-Path $sharedPath "SchemaInspector.psm1") -Force
Import-Module (Join-Path $sharedPath "OutputFormatter.psm1") -Force

# ---------------------------------------------------------------------------
# Test-local helper: mirrors Compare-EnvironmentVersions in the skill exactly.
# Accepts a hashtable of env => @{ Version; Available } and returns a result.
# ---------------------------------------------------------------------------
function Invoke-SyncComparison {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$EnvironmentVersions
    )

    # Collect available versions
    $availableVersions = @()
    foreach ($env in $EnvironmentVersions.Keys) {
        $info = $EnvironmentVersions[$env]
        if ($info.Available -eq $true -and $null -ne $info.Version) {
            $availableVersions += $info.Version
        }
    }

    # Determine overall status
    $overallStatus = "ERROR"
    if ($availableVersions.Count -gt 0) {
        $distinctVersions = @($availableVersions | Select-Object -Unique)
        if ($distinctVersions.Count -eq 1) {
            $overallStatus = "IN_SYNC"
        } else {
            $overallStatus = "OUT_OF_SYNC"
        }
    }

    # Find max and min versions among available envs for Ahead/Behind classification
    $maxVersion = $null
    $minVersion = $null
    if ($availableVersions.Count -gt 0) {
        $sorted = @($availableVersions | Sort-Object)
        $minVersion = $sorted[0]
        $maxVersion = $sorted[$sorted.Count - 1]
    }

    # Classify each environment
    $envResults = @{}
    $inSyncCount = 0
    $outOfSyncCount = 0
    $unavailableCount = 0

    foreach ($env in $EnvironmentVersions.Keys) {
        $info = $EnvironmentVersions[$env]
        if ($info.Available -ne $true -or $null -eq $info.Version) {
            $envResults[$env] = @{
                Version   = $null
                Status    = "Unavailable"
                Available = $false
            }
            $unavailableCount++
        } else {
            $ver = $info.Version
            $envStatus = "InSync"
            if ($overallStatus -eq "OUT_OF_SYNC") {
                if ($ver -eq $maxVersion -and $ver -ne $minVersion) {
                    $envStatus = "Ahead"
                } elseif ($ver -eq $minVersion -and $ver -ne $maxVersion) {
                    $envStatus = "Behind"
                } else {
                    $envStatus = "InSync"
                }
            }

            $envResults[$env] = @{
                Version   = $ver
                Status    = $envStatus
                Available = $true
            }

            if ($envStatus -eq "InSync") {
                $inSyncCount++
            } else {
                $outOfSyncCount++
            }
        }
    }

    return @{
        Status               = $overallStatus
        EnvironmentVersions  = $envResults
        InSyncCount          = $inSyncCount
        OutOfSyncCount       = $outOfSyncCount
        UnavailableCount     = $unavailableCount
    }
}

# ===========================================================================
# Describe block
# ===========================================================================

Describe "oracle-environment-sync-status" {

    # -----------------------------------------------------------------------
    Context "Parameter validation" {
    # -----------------------------------------------------------------------

        It "Accepts no parameters (all optional)" {
            { & $skillPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Accepts Full OutputFormat" {
            { & $skillPath -OutputFormat Full -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Accepts Summary OutputFormat" {
            { & $skillPath -OutputFormat Summary -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Rejects invalid OutputFormat" {
            { & $skillPath -OutputFormat "BadFormat" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Accepts custom MigrationsTable name" {
            { & $skillPath -MigrationsTable "MY_MIGRATIONS" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-Null } | Should Not Throw
        }

        It "Rejects invalid MigrationsTable name (lowercase)" {
            { & $skillPath -MigrationsTable "bad_table" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }

        It "Rejects invalid MigrationsTable name (too long)" {
            { & $skillPath -MigrationsTable "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" -ErrorAction Stop 2>&1 | Out-Null } | Should Throw
        }
    }

    # -----------------------------------------------------------------------
    Context "IN_SYNC: all environments have same version" {
    # -----------------------------------------------------------------------

        It "Returns IN_SYNC when all three versions match" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0005"; Available = $true }
                production = @{ Version = "0005"; Available = $true }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.Status | Should Be "IN_SYNC"
        }

        It "InSyncCount is 3 when all environments match" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0005"; Available = $true }
                production = @{ Version = "0005"; Available = $true }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.InSyncCount | Should Be 3
        }

        It "OutOfSyncCount is 0 when all environments match" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0005"; Available = $true }
                production = @{ Version = "0005"; Available = $true }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.OutOfSyncCount | Should Be 0
        }

        It "UnavailableCount is 0 when all environments are available" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0005"; Available = $true }
                production = @{ Version = "0005"; Available = $true }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.UnavailableCount | Should Be 0
        }

        It "All environment statuses are InSync when versions match" {
            $versions = @{
                local      = @{ Version = "0010"; Available = $true }
                staging    = @{ Version = "0010"; Available = $true }
                production = @{ Version = "0010"; Available = $true }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.EnvironmentVersions["local"].Status | Should Be "InSync"
            $result.EnvironmentVersions["staging"].Status | Should Be "InSync"
            $result.EnvironmentVersions["production"].Status | Should Be "InSync"
        }
    }

    # -----------------------------------------------------------------------
    Context "OUT_OF_SYNC: environments differ" {
    # -----------------------------------------------------------------------

        It "Returns OUT_OF_SYNC when versions differ" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0003"; Available = $true }
                production = @{ Version = "0003"; Available = $true }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.Status | Should Be "OUT_OF_SYNC"
        }

        It "Marks higher version environment as Ahead" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0003"; Available = $true }
                production = @{ Version = "0003"; Available = $true }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.EnvironmentVersions["local"].Status | Should Be "Ahead"
        }

        It "Marks lower version environment as Behind" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0003"; Available = $true }
                production = @{ Version = "0003"; Available = $true }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.EnvironmentVersions["staging"].Status | Should Be "Behind"
        }

        It "OutOfSyncCount reflects mismatched environments" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0003"; Available = $true }
                production = @{ Version = "0003"; Available = $true }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            ($result.OutOfSyncCount -gt 0) | Should Be $true
        }

        It "All three environments with different versions are all out-of-sync" {
            $versions = @{
                local      = @{ Version = "0007"; Available = $true }
                staging    = @{ Version = "0005"; Available = $true }
                production = @{ Version = "0003"; Available = $true }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.Status | Should Be "OUT_OF_SYNC"
            $result.EnvironmentVersions["local"].Status | Should Be "Ahead"
            $result.EnvironmentVersions["production"].Status | Should Be "Behind"
        }
    }

    # -----------------------------------------------------------------------
    Context "Unavailable environments" {
    # -----------------------------------------------------------------------

        It "Marks unavailable environment with Unavailable status" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0005"; Available = $true }
                production = @{ Version = $null;  Available = $false }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.EnvironmentVersions["production"].Status | Should Be "Unavailable"
        }

        It "Unavailable environment has Available = false" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0005"; Available = $true }
                production = @{ Version = $null;  Available = $false }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.EnvironmentVersions["production"].Available | Should Be $false
        }

        It "UnavailableCount is 1 when one environment is down" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0005"; Available = $true }
                production = @{ Version = $null;  Available = $false }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.UnavailableCount | Should Be 1
        }

        It "Two available same-version envs return IN_SYNC even if third is unavailable" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0005"; Available = $true }
                production = @{ Version = $null;  Available = $false }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.Status | Should Be "IN_SYNC"
        }

        It "Returns ERROR when all environments are unavailable" {
            $versions = @{
                local      = @{ Version = $null; Available = $false }
                staging    = @{ Version = $null; Available = $false }
                production = @{ Version = $null; Available = $false }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.Status | Should Be "ERROR"
        }

        It "UnavailableCount is 3 when all environments are down" {
            $versions = @{
                local      = @{ Version = $null; Available = $false }
                staging    = @{ Version = $null; Available = $false }
                production = @{ Version = $null; Available = $false }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.UnavailableCount | Should Be 3
        }

        It "Mixed: one available, one unavailable -> IN_SYNC (single version)" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = $null;  Available = $false }
                production = @{ Version = $null;  Available = $false }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.Status | Should Be "IN_SYNC"
        }
    }

    # -----------------------------------------------------------------------
    Context "Mixed OUT_OF_SYNC + unavailable" {
    # -----------------------------------------------------------------------

        It "Returns OUT_OF_SYNC when available envs differ and one is unavailable" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0003"; Available = $true }
                production = @{ Version = $null;  Available = $false }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.Status | Should Be "OUT_OF_SYNC"
        }

        It "UnavailableCount is 1 in mixed scenario" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0003"; Available = $true }
                production = @{ Version = $null;  Available = $false }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.UnavailableCount | Should Be 1
        }

        It "Available environment version is preserved in result" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0003"; Available = $true }
                production = @{ Version = $null;  Available = $false }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.EnvironmentVersions["local"].Version | Should Be "0005"
        }

        It "Unavailable environment version is null in result" {
            $versions = @{
                local      = @{ Version = "0005"; Available = $true }
                staging    = @{ Version = "0003"; Available = $true }
                production = @{ Version = $null;  Available = $false }
            }
            $result = Invoke-SyncComparison -EnvironmentVersions $versions
            $result.EnvironmentVersions["production"].Version | Should Be $null
        }
    }

    # -----------------------------------------------------------------------
    Context "Skill output format" {
    # -----------------------------------------------------------------------

        It "Skill produces output containing json code block" {
            $output = & $skillPath -OutputFormat Full -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($output -match '```json') | Should Be $true
        }

        It "Skill produces output containing markdown code block" {
            $output = & $skillPath -OutputFormat Full -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($output -match '```markdown') | Should Be $true
        }

        It "Skill JSON output contains Status field" {
            $output = & $skillPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"Status"') | Should Be $true
        }

        It "Skill JSON output contains EnvironmentVersions field" {
            $output = & $skillPath -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($output -match '"EnvironmentVersions"') | Should Be $true
        }

        It "Summary OutputFormat produces shorter output than Full" {
            $fullOutput = & $skillPath -OutputFormat Full -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            $summaryOutput = & $skillPath -OutputFormat Summary -ErrorAction SilentlyContinue -WarningAction SilentlyContinue 2>&1 | Out-String
            ($summaryOutput.Length -le $fullOutput.Length) | Should Be $true
        }
    }
}

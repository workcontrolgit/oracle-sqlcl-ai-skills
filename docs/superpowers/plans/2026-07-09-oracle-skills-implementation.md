# Oracle Skills Taxonomy Implementation Plan (PowerShell)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 10 new Oracle database skills across two tiers (Dev Support + CI/CD Automation) in four phases using PowerShell, enabling developers to troubleshoot migrations locally and pipelines to validate schema consistency across environments.

**Architecture:** 
- Tier 2 (Dev Support): 5 skills for local troubleshooting (migrations, conflicts, resets, permissions)
- Tier 3 (CI/CD Automation): 5 skills for cross-environment validation (schema diffs, pre-deploy checks, drift detection)
- Shared layer: PowerShell modules for connection management, schema inspection, output formatting
- Integration: SQLcl/sqlplus for Oracle queries, environment variables for multi-environment configuration
- Testing: Pester framework for unit tests, manual validation against local Oracle XE

**Tech Stack:** PowerShell 5.1+, Oracle SQLcl or sqlplus, JSON/XML output formatting

---

## File Structure

```
.claude/skills/oracle-skills/
├── shared/
│   ├── OracleConnection.psm1       # Multi-env connection management
│   ├── SchemaInspector.psm1        # Schema metadata queries
│   └── OutputFormatter.psm1        # JSON + markdown output
├── tier2/
│   ├── oracle-migration-status.ps1  # Check migration status
│   ├── oracle-migration-diff.ps1    # Compare schema vs. migrations
│   ├── oracle-schema-conflict-detect.ps1  # Detect manual changes
│   ├── oracle-schema-reset.ps1      # Reset schema to known state
│   └── oracle-user-permissions.ps1  # Check user privileges
├── tier3/
│   ├── oracle-schema-compare-environments.ps1  # Compare dev/staging/prod
│   ├── oracle-migration-validate.ps1           # Validate migrations applied
│   ├── oracle-pre-deploy-check.ps1             # Pre-deployment validation
│   ├── oracle-schema-drift-detect.ps1          # Detect manual changes
│   └── oracle-environment-sync-status.ps1      # Check env sync status
├── tests/
│   ├── OracleConnection.Tests.ps1
│   ├── SchemaInspector.Tests.ps1
│   ├── Tier2.Integration.Tests.ps1
│   └── Tier3.Integration.Tests.ps1
├── config/
│   ├── environments.json           # Dev/staging/prod connection configs
│   └── credentials-example.json    # Credential template
└── README.md
```

---

## Phase 1: Shared Infrastructure & Configuration

### Task 1: Set Up Project Structure & Configuration

**Files:**
- Create: `.claude/skills/oracle-skills/` directory structure
- Create: `.claude/skills/oracle-skills/config/environments.json`
- Create: `.claude/skills/oracle-skills/README.md`

- [ ] **Step 1: Create directory structure**

```powershell
$dirs = @(
    ".\.claude\skills\oracle-skills\shared",
    ".\.claude\skills\oracle-skills\tier2",
    ".\.claude\skills\oracle-skills\tier3",
    ".\.claude\skills\oracle-skills\tests",
    ".\.claude\skills\oracle-skills\config"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

Write-Host "Created Oracle skills directory structure"
```

- [ ] **Step 2: Create environments configuration**

Create `.\.claude\skills\oracle-skills\config\environments.json`:
```json
{
  "environments": {
    "local": {
      "host": "localhost",
      "port": 1521,
      "service": "XEPDB1",
      "username": "hr",
      "password": "${env:ORACLE_HR_PASSWORD}",
      "sqlclAlias": "hr@//localhost:1521/XEPDB1",
      "description": "Local development (Oracle XE)"
    },
    "staging": {
      "host": "${env:STAGING_ORACLE_HOST}",
      "port": 1521,
      "service": "${env:STAGING_ORACLE_SERVICE}",
      "username": "${env:STAGING_ORACLE_USER}",
      "password": "${env:STAGING_ORACLE_PASSWORD}",
      "sqlclAlias": "${env:STAGING_ORACLE_USER}@//${env:STAGING_ORACLE_HOST}:1521/${env:STAGING_ORACLE_SERVICE}",
      "description": "Staging environment"
    },
    "production": {
      "host": "${env:PROD_ORACLE_HOST}",
      "port": 1521,
      "service": "${env:PROD_ORACLE_SERVICE}",
      "username": "${env:PROD_ORACLE_USER}",
      "password": "${env:PROD_ORACLE_PASSWORD}",
      "sqlclAlias": "${env:PROD_ORACLE_USER}@//${env:PROD_ORACLE_HOST}:1521/${env:PROD_ORACLE_SERVICE}",
      "description": "Production environment"
    }
  },
  "defaults": {
    "timeout": 30,
    "pagesize": 200,
    "linesize": 200,
    "tool": "sqlcl"
  }
}
```

- [ ] **Step 3: Create credentials example**

Create `.\.claude\skills\oracle-skills\config\credentials-example.json`:
```json
{
  "_comment": "Copy to credentials.json and fill with actual values. Add to .gitignore.",
  "staging": {
    "host": "staging-oracle.company.com",
    "user": "staging_admin",
    "password": "***"
  },
  "production": {
    "host": "prod-oracle.company.com",
    "user": "prod_admin",
    "password": "***"
  }
}
```

- [ ] **Step 4: Create README.md**

Create `.\.claude\skills\oracle-skills\README.md`:
```markdown
# Oracle Skills Taxonomy (PowerShell)

Three-tier hierarchy of Oracle database skills supporting exploration, dev troubleshooting, and CI/CD automation.

## Setup

1. **Install dependencies:**
   - Oracle SQLcl: Download from Oracle (includes sqlplus-compatible interface)
   - Pester: `Install-Module -Name Pester -Force` (for testing)

2. **Configure environments:**
   - Copy `config/credentials-example.json` to `config/credentials.json`
   - Fill in staging/production connection details
   - Set environment variables:
     ```powershell
     $env:ORACLE_HR_PASSWORD = "HrUser_2026"
     $env:STAGING_ORACLE_HOST = "staging.example.com"
     # etc.
     ```

3. **Import shared modules:**
   ```powershell
   Import-Module ".\.claude\skills\oracle-skills\shared\OracleConnection.psm1"
   Import-Module ".\.claude\skills\oracle-skills\shared\SchemaInspector.psm1"
   Import-Module ".\.claude\skills\oracle-skills\shared\OutputFormatter.psm1"
   ```

## Tiers

### Tier 1: Exploration (9 existing skills)
- oracle-database-info, oracle-hr-query, oracle-search-tables, etc.

### Tier 2: Dev Support (5 new skills)
- oracle-migration-status, oracle-migration-diff, oracle-schema-conflict-detect
- oracle-schema-reset, oracle-user-permissions

### Tier 3: CI/CD Automation (5 new skills)
- oracle-schema-compare-environments, oracle-migration-validate, oracle-pre-deploy-check
- oracle-schema-drift-detect, oracle-environment-sync-status

## Running Skills

```powershell
# Dev support examples
& ".\.claude\skills\oracle-skills\tier2\oracle-migration-status.ps1" -Environment local

# CI/CD examples
& ".\.claude\skills\oracle-skills\tier3\oracle-pre-deploy-check.ps1" -Environment staging
```

## Testing

```powershell
# Run all tests
Invoke-Pester ".\.claude\skills\oracle-skills\tests\"

# Run specific test
Invoke-Pester ".\.claude\skills\oracle-skills\tests\OracleConnection.Tests.ps1"
```
```

- [ ] **Step 5: Commit**

```powershell
cd c:\apps\oracle
git init  # If not already initialized
git add .claude/skills/oracle-skills/
git commit -m "feat: initialize Oracle skills project structure (PowerShell)"
```

---

### Task 2: Implement OracleConnection Module

**Files:**
- Create: `.\.claude\skills\oracle-skills\shared\OracleConnection.psm1`
- Create: `.\.claude\skills\oracle-skills\tests\OracleConnection.Tests.ps1`

- [ ] **Step 1: Write Pester tests for connection module**

Create `.\.claude\skills\oracle-skills\tests\OracleConnection.Tests.ps1`:
```powershell
<#
.SYNOPSIS
    Pester tests for OracleConnection module
#>

BeforeAll {
    $modulePath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared\OracleConnection.psm1"
    Import-Module $modulePath -Force
}

Describe "OracleConnection" {
    
    Context "Get-EnvironmentConfig" {
        It "Returns local config" {
            $config = Get-EnvironmentConfig -Environment "local"
            $config.host | Should -Be "localhost"
            $config.service | Should -Be "XEPDB1"
            $config.username | Should -Be "hr"
        }
        
        It "Returns staging config" {
            $config = Get-EnvironmentConfig -Environment "staging"
            $config.host | Should -Not -BeNullOrEmpty
            $config.service | Should -Not -BeNullOrEmpty
        }
        
        It "Returns production config" {
            $config = Get-EnvironmentConfig -Environment "production"
            $config.host | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-OracleQuery" {
        It "Executes a test query" {
            # Mock sqlcl execution
            $result = Invoke-OracleQuery -Environment "local" -Query "SELECT 1 as test_col FROM dual"
            $result | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Test-OracleConnection" {
        It "Validates connection to local environment" {
            $testResult = Test-OracleConnection -Environment "local"
            $testResult | Should -Be $true
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```powershell
cd c:\apps\oracle\.claude\skills\oracle-skills
Invoke-Pester tests\OracleConnection.Tests.ps1 -Output Detailed
```

Expected: Tests fail because module doesn't exist yet.

- [ ] **Step 3: Implement OracleConnection module**

Create `.\.claude\skills\oracle-skills\shared\OracleConnection.psm1`:
```powershell
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
        if ($value -match '^\$\{env:') {
            $envVar = $value -replace '^\$\{env:(\w+)\}', '$1'
            $expandedConfig[$key] = [System.Environment]::GetEnvironmentVariable($envVar)
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
    
    $config = Get-EnvironmentConfig -Environment $Environment
    
    # Build sqlcl command
    $sqlScript = @"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
SET ECHO OFF
$Query
EXIT;
"@
    
    try {
        # Execute via sqlcl
        $result = $sqlScript | & sql $config.sqlclAlias 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Oracle query failed: $result"
            return $null
        }
        
        # Parse output based on format
        switch ($OutputFormat) {
            "JSON" {
                # Convert to JSON (simplified - real implementation would be more robust)
                $lines = $result | Where-Object { $_ -match "^\|" }
                return $lines | ConvertFrom-Csv
            }
            default {
                return $result
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
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment
    )
    
    try {
        $config = Get-EnvironmentConfig -Environment $Environment
        $result = Invoke-OracleQuery -Environment $Environment -Query "SELECT 1 FROM dual"
        return $null -ne $result
    }
    catch {
        return $false
    }
}

function Get-OracleVersion {
    <#
    .SYNOPSIS
        Get Oracle database version
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment
    )
    
    $result = Invoke-OracleQuery -Environment $Environment -Query "SELECT * FROM v`$version WHERE banner LIKE '%Oracle%' FETCH FIRST 1 ROW ONLY"
    return $result
}

# Export public functions
Export-ModuleMember -Function @(
    "Get-EnvironmentConfig",
    "Invoke-OracleQuery",
    "Test-OracleConnection",
    "Get-OracleVersion"
)
```

- [ ] **Step 4: Run tests to verify they pass**

```powershell
cd c:\apps\oracle\.claude\skills\oracle-skills
Invoke-Pester tests\OracleConnection.Tests.ps1 -Output Detailed
```

Expected: 3+ passed (or marked as skipped if Oracle not available for live testing)

- [ ] **Step 5: Commit**

```powershell
cd c:\apps\oracle
git add .claude\skills\oracle-skills\shared\OracleConnection.psm1
git add .claude\skills\oracle-skills\tests\OracleConnection.Tests.ps1
git commit -m "feat: implement OracleConnection module (multi-environment)"
```

---

### Task 3: Implement SchemaInspector Module

**Files:**
- Create: `.\.claude\skills\oracle-skills\shared\SchemaInspector.psm1`
- Create: `.\.claude\skills\oracle-skills\tests\SchemaInspector.Tests.ps1`

- [ ] **Step 1: Write Pester tests for SchemaInspector**

Create `.\.claude\skills\oracle-skills\tests\SchemaInspector.Tests.ps1`:
```powershell
<#
.SYNOPSIS
    Pester tests for SchemaInspector module
#>

BeforeAll {
    $modulePath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared\SchemaInspector.psm1"
    Import-Module $modulePath -Force
}

Describe "SchemaInspector" {
    
    Context "Get-TableList" {
        It "Returns list of tables" {
            $tables = Get-TableList -Environment "local"
            $tables | Should -Not -BeNullOrEmpty
            $tables | Should -Contain "EMPLOYEES"
        }
    }
    
    Context "Get-TableColumns" {
        It "Returns columns for EMPLOYEES table" {
            $columns = Get-TableColumns -Environment "local" -TableName "EMPLOYEES"
            $columns | Should -Not -BeNullOrEmpty
            $columns | Should -Contain "EMPLOYEE_ID"
        }
    }
    
    Context "Test-TableExists" {
        It "Confirms EMPLOYEES table exists" {
            $exists = Test-TableExists -Environment "local" -TableName "EMPLOYEES"
            $exists | Should -Be $true
        }
        
        It "Confirms NONEXISTENT table does not exist" {
            $exists = Test-TableExists -Environment "local" -TableName "NONEXISTENT"
            $exists | Should -Be $false
        }
    }
    
    Context "Get-TableConstraints" {
        It "Returns constraints for EMPLOYEES table" {
            $constraints = Get-TableConstraints -Environment "local" -TableName "EMPLOYEES"
            $constraints | Should -Not -BeNullOrEmpty
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd c:\apps\oracle\.claude\skills\oracle-skills
Invoke-Pester tests\SchemaInspector.Tests.ps1 -Output Detailed
```

Expected: Tests fail because module doesn't exist.

- [ ] **Step 3: Implement SchemaInspector module**

Create `.\.claude\skills\oracle-skills\shared\SchemaInspector.psm1`:
```powershell
<#
.SYNOPSIS
    Schema metadata inspection for Oracle databases
#>

# Require OracleConnection module
Import-Module (Join-Path $PSScriptRoot "OracleConnection.psm1") -Force

function Get-TableList {
    <#
    .SYNOPSIS
        Get list of all tables in schema
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment
    )
    
    $query = @"
SELECT table_name
FROM user_tables
ORDER BY table_name
"@
    
    $result = Invoke-OracleQuery -Environment $Environment -Query $query
    
    # Parse output - extract table names from result
    $tables = @()
    foreach ($line in $result) {
        if ($line -match '^\s*([A-Z_]+)\s*$') {
            $tables += $matches[1]
        }
    }
    
    return $tables
}

function Get-TableColumns {
    <#
    .SYNOPSIS
        Get columns for a specific table
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment,
        
        [Parameter(Mandatory=$true)]
        [string]$TableName
    )
    
    $query = @"
SELECT column_name, data_type, nullable
FROM user_tab_columns
WHERE table_name = UPPER('$TableName')
ORDER BY column_id
"@
    
    $result = Invoke-OracleQuery -Environment $Environment -Query $query
    
    # Parse output - extract column names
    $columns = @()
    foreach ($line in $result) {
        if ($line -match '^\s*([A-Z_]+)\s+(\w+)\s+([YN])\s*$') {
            $columns += @{
                Name = $matches[1]
                DataType = $matches[2]
                Nullable = $matches[3] -eq 'Y'
            }
        }
    }
    
    return $columns
}

function Test-TableExists {
    <#
    .SYNOPSIS
        Check if table exists in schema
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment,
        
        [Parameter(Mandatory=$true)]
        [string]$TableName
    )
    
    $query = @"
SELECT COUNT(*)
FROM user_tables
WHERE table_name = UPPER('$TableName')
"@
    
    $result = Invoke-OracleQuery -Environment $Environment -Query $query
    
    # Parse result to check count > 0
    if ($result -match '1') {
        return $true
    }
    
    return $false
}

function Get-TableConstraints {
    <#
    .SYNOPSIS
        Get constraints for a specific table
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment,
        
        [Parameter(Mandatory=$true)]
        [string]$TableName
    )
    
    $query = @"
SELECT constraint_name, constraint_type, column_name
FROM user_cons_columns uc
JOIN user_constraints c ON uc.constraint_name = c.constraint_name
WHERE c.table_name = UPPER('$TableName')
ORDER BY constraint_name, position
"@
    
    $result = Invoke-OracleQuery -Environment $Environment -Query $query
    $constraints = @()
    
    # Parse output and group by constraint
    $constraintMap = @{}
    foreach ($line in $result) {
        if ($line -match '^\s*([A-Z_]+)\s+([A-Z])\s+([A-Z_]+)\s*$') {
            $constName = $matches[1]
            $constType = $matches[2]
            $colName = $matches[3]
            
            if (-not $constraintMap.ContainsKey($constName)) {
                $constraintMap[$constName] = @{
                    Name = $constName
                    Type = $constType
                    Columns = @()
                }
            }
            $constraintMap[$constName].Columns += $colName
        }
    }
    
    return $constraintMap.Values
}

# Export public functions
Export-ModuleMember -Function @(
    "Get-TableList",
    "Get-TableColumns",
    "Test-TableExists",
    "Get-TableConstraints"
)
```

- [ ] **Step 4: Run tests to verify they pass**

```powershell
cd c:\apps\oracle\.claude\skills\oracle-skills
Invoke-Pester tests\SchemaInspector.Tests.ps1 -Output Detailed
```

Expected: Tests pass or skip gracefully

- [ ] **Step 5: Commit**

```powershell
cd c:\apps\oracle
git add .claude\skills\oracle-skills\shared\SchemaInspector.psm1
git add .claude\skills\oracle-skills\tests\SchemaInspector.Tests.ps1
git commit -m "feat: implement SchemaInspector module"
```

---

### Task 4: Implement OutputFormatter Module

**Files:**
- Create: `.\.claude\skills\oracle-skills\shared\OutputFormatter.psm1`
- Create: `.claude\skills\oracle-skills\tests\OutputFormatter.Tests.ps1`

- [ ] **Step 1: Write tests for OutputFormatter**

Create `.\.claude\skills\oracle-skills\tests\OutputFormatter.Tests.ps1`:
```powershell
<#
.SYNOPSIS
    Pester tests for OutputFormatter module
#>

BeforeAll {
    $modulePath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared\OutputFormatter.psm1"
    Import-Module $modulePath -Force
}

Describe "OutputFormatter" {
    
    Context "ConvertTo-MarkdownTable" {
        It "Converts array to markdown table" {
            $data = @(
                @{ Name = "EMPLOYEES"; Type = "TABLE" },
                @{ Name = "DEPARTMENTS"; Type = "TABLE" }
            )
            
            $md = ConvertTo-MarkdownTable -Data $data
            $md | Should -Match "Name"
            $md | Should -Match "EMPLOYEES"
        }
    }
    
    Context "ConvertTo-DiagnosticJson" {
        It "Creates diagnostic JSON output" {
            $result = @{
                Status = "PASS"
                Message = "All checks passed"
                Details = @{ Count = 5 }
            }
            
            $json = ConvertTo-DiagnosticJson -Result $result
            $json | Should -Match '"Status":"PASS"'
        }
    }
    
    Context "Format-DiagnosticOutput" {
        It "Creates combined JSON + markdown output" {
            $result = @{
                Title = "Test Result"
                Status = "PASS"
                Message = "All checks passed"
            }
            
            $output = Format-DiagnosticOutput -Result $result
            $output | Should -Match '```json'
            $output | Should -Match '```markdown'
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```powershell
cd c:\apps\oracle\.claude\skills\oracle-skills
Invoke-Pester tests\OutputFormatter.Tests.ps1 -Output Detailed
```

Expected: Tests fail.

- [ ] **Step 3: Implement OutputFormatter module**

Create `.\.claude\skills\oracle-skills\shared\OutputFormatter.psm1`:
```powershell
<#
.SYNOPSIS
    Output formatting utilities (JSON + Markdown for both humans and pipelines)
#>

function ConvertTo-MarkdownTable {
    <#
    .SYNOPSIS
        Convert array of objects to markdown table
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$Data,
        
        [string[]]$Properties
    )
    
    if ($Data.Count -eq 0) {
        return "| No data |"
    }
    
    # Determine properties to include
    if (-not $Properties) {
        $Properties = $Data[0].PSObject.Properties.Name
    }
    
    # Build header
    $header = "| " + ($Properties -join " | ") + " |"
    $separator = "|" + (($Properties | ForEach-Object { " --- " }) -join "|") + "|"
    
    # Build rows
    $rows = $Data | ForEach-Object {
        $obj = $_
        $cells = $Properties | ForEach-Object { $obj.$_ }
        "| " + ($cells -join " | ") + " |"
    }
    
    return @($header, $separator) + $rows | Join-String -Separator "`n"
}

function ConvertTo-DiagnosticJson {
    <#
    .SYNOPSIS
        Convert result to diagnostic JSON
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Result,
        
        [int]$Indent = 2
    )
    
    return $Result | ConvertTo-Json -Depth 10 -Compress:$false
}

function Format-DiagnosticOutput {
    <#
    .SYNOPSIS
        Format diagnostic output with JSON + Markdown
    .DESCRIPTION
        Creates combined output with JSON block (for pipelines) and markdown block (for humans)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Result
    )
    
    $title = $Result.Title -or "Diagnostic Result"
    $status = $Result.Status -or "UNKNOWN"
    $message = $Result.Message -or ""
    $details = $Result.Details -or @{}
    
    $output = @()
    
    # JSON block (for pipeline parsing)
    $output += "``````json"
    $output += ($Result | ConvertTo-Json -Depth 10)
    $output += "``````"
    $output += ""
    
    # Markdown block (for human reading)
    $output += "``````markdown"
    $output += "# $title"
    $output += "**Status:** $status"
    $output += "**Message:** $message"
    $output += ""
    $output += "## Details"
    
    foreach ($key in $details.Keys) {
        $value = $details[$key]
        if ($value -is [array]) {
            $output += "- **$key:** $($value -join ', ')"
        } else {
            $output += "- **$key:** $value"
        }
    }
    
    $output += "``````"
    
    return $output -join "`n"
}

function Format-SuccessOutput {
    <#
    .SYNOPSIS
        Format success diagnostic output
    #>
    param(
        [string]$Message,
        [hashtable]$Details
    )
    
    return Format-DiagnosticOutput -Result @{
        Title = "Success"
        Status = "PASS"
        Message = $Message
        Details = $Details
    }
}

function Format-FailureOutput {
    <#
    .SYNOPSIS
        Format failure diagnostic output
    #>
    param(
        [string]$Message,
        [hashtable]$Details
    )
    
    return Format-DiagnosticOutput -Result @{
        Title = "Failure"
        Status = "FAIL"
        Message = $Message
        Details = $Details
    }
}

# Export public functions
Export-ModuleMember -Function @(
    "ConvertTo-MarkdownTable",
    "ConvertTo-DiagnosticJson",
    "Format-DiagnosticOutput",
    "Format-SuccessOutput",
    "Format-FailureOutput"
)
```

- [ ] **Step 4: Run tests to verify they pass**

```powershell
cd c:\apps\oracle\.claude\skills\oracle-skills
Invoke-Pester tests\OutputFormatter.Tests.ps1 -Output Detailed
```

Expected: Tests pass.

- [ ] **Step 5: Commit**

```powershell
cd c:\apps\oracle
git add .claude\skills\oracle-skills\shared\OutputFormatter.psm1
git add .claude\skills\oracle-skills\tests\OutputFormatter.Tests.ps1
git commit -m "feat: implement OutputFormatter module"
```

---

## Phase 2: Tier 2 Dev Support Skills (Tasks 5-9)

*(Following identical pattern to Phase 1: Pester tests → implementation → skill doc → commit)*

### Task 5: Implement `oracle-migration-status` Skill
- **Script:** `.\.claude\skills\oracle-skills\tier2\oracle-migration-status.ps1`
- **Tests:** Query schema_migrations table, parse applied/failed migrations, format diagnostic output
- **Outputs:** JSON + markdown showing current version, total applied, total failed
- **Skill Doc:** Migration status definition and usage

### Task 6: Implement `oracle-migration-diff` Skill
- **Script:** Compare current schema against expected migration target
- **Tests:** Identify missing columns, constraints, tables
- **Outputs:** Diff report (JSON + markdown)

### Task 7: Implement `oracle-schema-conflict-detect` Skill
- **Script:** Detect manual schema changes outside migrations
- **Tests:** Compare migrations vs. actual schema, identify drift
- **Outputs:** Conflict report with recommendations

### Task 8: Implement `oracle-schema-reset` Skill
- **Script:** Safely reset schema to known state (dev only)
- **Tests:** Drop/recreate schema, re-apply init scripts, seed data
- **Outputs:** Reset confirmation + final schema state
- **Security:** Dev environment only (hardcoded check)

### Task 9: Implement `oracle-user-permissions` Skill
- **Script:** Check user/role privileges and identify gaps
- **Tests:** Query DBA_ROLE_PRIVS, SESSION_PRIVS, recommend missing grants
- **Outputs:** Permission report with recommendations

---

## Phase 3-4: Tier 3 CI/CD Automation Skills (Tasks 10-14)

*(Following same pattern, with pipeline-friendly output format)*

### Task 10: Implement `oracle-schema-compare-environments`
- **Inputs:** Source environment, target environment
- **Tests:** Schema diff between two environments
- **Outputs:** JSON (for pipeline) + markdown summary

### Task 11: Implement `oracle-migration-validate`
- **Inputs:** Environment, expected migration list (from code)
- **Tests:** Verify all expected migrations applied
- **Outputs:** Pass/fail checklist

### Task 12: Implement `oracle-pre-deploy-check`
- **Inputs:** Target environment (staging/prod)
- **Tests:** Run all pre-deploy validations (schema, migrations, connectivity, users)
- **Outputs:** Single pass/fail gate for deployment

### Task 13: Implement `oracle-schema-drift-detect`
- **Inputs:** Environment, baseline version
- **Tests:** Find manual changes outside migrations
- **Outputs:** Drift report

### Task 14: Implement `oracle-environment-sync-status`
- **Inputs:** None (queries all three environments)
- **Tests:** Check version parity across dev/staging/prod
- **Outputs:** Sync matrix showing which environments are ahead/behind

---

## Testing Strategy

### Unit Tests (Pester)
- Mock OracleConnection calls
- Test output formatting
- Test logic in isolation

### Integration Tests
- Run against local Oracle XE container
- Test multi-environment connection logic
- Verify actual schema queries

### Pipeline Tests
- Simulate CI/CD invocation
- Verify JSON output parsing
- Test exit codes (0=pass, 1=fail)

---

## Acceptance Criteria

✓ Phase 1: All 3 shared modules implemented, tested, committed
✓ Phase 2: All 5 Tier 2 skills implemented with PowerShell scripts, Pester tests, skill docs
✓ Phase 3-4: All 5 Tier 3 skills implemented, tested, pipeline-ready
✓ All tests pass locally against Oracle XE
✓ Skills work across dev/staging/prod environments via environment variables
✓ JSON + markdown output verified for both dev and pipeline use

---

## Deliverables

1. **Shared Modules:** 3 PowerShell modules (.psm1) with connection, inspection, formatting
2. **Skills:** 10 PowerShell scripts (.ps1) for Tier 2 + Tier 3
3. **Skill Definitions:** 10 markdown docs (.md) with usage, inputs, outputs, examples
4. **Tests:** Pester test files for all modules and skills
5. **Configuration:** environments.json, credentials-example.json
6. **Documentation:** README.md, inline script comments
7. **Commit History:** Clean, atomic commits per task


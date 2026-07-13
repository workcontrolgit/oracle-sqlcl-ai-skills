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

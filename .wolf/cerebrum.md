# Cerebrum

> OpenWolf's learning memory. Updated automatically as the AI learns from interactions.
> Do not edit manually unless correcting an error.
> Last updated: 2026-07-09

## User Preferences

<!-- How the user likes things done. Code style, tools, patterns, communication. -->

## Key Learnings

- **Project:** oracle
- **Description:** This workspace provides a local Oracle XE database in Docker with an initialized HR schema and sample data.
- **Pester 3.4.0 Compatibility:** BeforeAll/AfterAll not supported at script root level; move `Import-Module` to top-level script scope. Use Pester v3 assertions: `Should Be`, `Should Not`, `Should Contain` (no `-` prefix). Avoid `-BeOfType`, `-Not`, `-BeNullOrEmpty` syntax; use comparisons instead.
- **OracleConnection Module:** Get-EnvironmentConfig uses regex `^\$\{env:(\w+)\}` to detect env vars, returns hashtable with expanded values, warns if vars unset. Module successfully handles multi-env (local/staging/prod) configurations from JSON.
- **Task 2 Security Hardening:** Implemented SQL injection prevention via command whitelist (SELECT/INSERT/UPDATE/DELETE only), multi-statement detection, timeout parameter, explicit CSV delimiter, error propagation (no SilentlyContinue), and fail-fast for missing required env vars.
- **SchemaInspector Table Name Validation:** Use regex `^[A-Z0-9_]{1,30}$` to validate table names before SQL interpolation. This prevents SQL injection in Get-TableColumns, Test-TableExists, Get-TableConstraints. Validates input before .ToUpper() conversion for consistency with Oracle naming.
- **Task 4 OutputFormatter Patterns:** (1) Always escape markdown special chars (| and \) in table cells before joining - use `-replace` in correct order (backslash first, then pipe). (2) Markdown table format is fragile - pipes split columns, backslashes escape. (3) Add try-catch to ConvertTo-Json calls for robustness. (4) Test edge cases for output formatters (empty strings, nulls, special chars).


## Do-Not-Repeat

<!-- Mistakes made and corrected. Each entry prevents the same mistake recurring. -->
<!-- Format: [YYYY-MM-DD] Description of what went wrong and what to do instead. -->

- [2026-07-09] Pester v3 assertion syntax: Use `($value1 -gt $value2) | Should Be $true` instead of `$value1 | Should Be -GT $value2`. Pester v3 doesn't support the `-GT` syntax directly in assertions.
- [2026-07-09] Markdown special characters in table cells: ALWAYS escape pipe (|) and backslash (\) characters before building markdown tables. Use `-replace '\\', '\\'` first, then `-replace '\|', '\|'` to prevent table structure corruption.
- [2026-07-09] PowerShell string escaping in -replace operations: When escaping special regex chars, remember single backslash in -replace pattern needs double backslash in PowerShell string. Format: `$value -replace '\\', '\\'` for backslash, `$value -replace '\|', '\|'` for pipe.
- [2026-07-09] Always add try-catch to ConvertTo-Json calls: JSON conversion can fail with circular references or unusual types. Wrap in try-catch with error message and fallback return value (empty hashtable as JSON).

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->

## Task 5 Learnings

- **Pester v3 Output Parameter:** Invoke-Pester in Pester v3 does not support -Output parameter; use -OutputFormat with values "LegacyNUnitXml" or "NUnitXml" only. Run without parameters for default display.
- **oracle-migration-status Architecture:** Skill script queries migrations table via SchemaInspector's Test-TableExists + OracleConnection's Invoke-OracleQuery. Returns formatted JSON + markdown blocks via OutputFormatter.Format-SuccessOutput/Format-FailureOutput.
- **Migration Status Detection:** Parse migration_status column for patterns: SUCCESS/APPLIED/COMPLETED for applied, FAIL/ERROR/FAILED for failures, PENDING/UNAPPLIED/WAITING for pending. Handle status inconsistencies across database versions.
- **Skill vs Module Distinction:** Skill scripts are .ps1 files invoked directly (& script.ps1 params), not imported as modules. They can import shared modules but don't export functions.

## Task 6 Learnings

- **Schema Diff Architecture:** oracle-migration-diff queries current schema via SchemaInspector (Get-TableList, Get-TableColumns, Get-TableConstraints) and compares against baseline expected state. Identifies missing tables, columns, and constraints. Outputs JSON + markdown via OutputFormatter.
- **Baseline Schema Approach:** Current implementation uses HR schema baseline (EMPLOYEES, DEPARTMENTS, JOBS, LOCATIONS, COUNTRIES, REGIONS tables). Can be enhanced to support migration metadata-driven expected state in future iterations.
- **Migration Version Detection:** Query migrations table with WHERE migration_status IN ('SUCCESS','APPLIED','COMPLETED','1') to find latest applied version. Handle inconsistent status values across database versions.
- **Schema Diff Output:** JSON includes counts of missing tables/columns/constraints; Details section contains arrays of diff objects (Table, Column/Constraint, Type fields). Status is "PASS" (no diffs) or "DIFFERENCES_FOUND" (diffs present).

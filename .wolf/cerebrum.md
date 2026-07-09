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


## Do-Not-Repeat

<!-- Mistakes made and corrected. Each entry prevents the same mistake recurring. -->
<!-- Format: [YYYY-MM-DD] Description of what went wrong and what to do instead. -->

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->

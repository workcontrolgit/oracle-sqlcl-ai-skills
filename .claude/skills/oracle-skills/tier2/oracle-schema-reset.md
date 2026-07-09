# oracle-schema-reset Skill

## Overview

`oracle-schema-reset` safely resets the Oracle database schema to a known state. **Dev environment only** (local). This is a high-risk operation that permanently drops all user tables.

## Security

**DEV ENVIRONMENT ONLY.** The skill:
- **Rejects** staging and production attempts (hardcoded check, not configuration-dependent)
- **Requires** explicit confirmation via `-ConfirmReset` flag
- **Logs** all reset operations for audit trail
- **Validates** table names before SQL interpolation (regex: `^[A-Z0-9_]{1,30}$`)

## Parameters

### `-Environment` (Mandatory)
Target environment. Must be `"local"` (dev only). Any other value triggers immediate rejection with exit code 1.

**Valid values:**
- `local` — Development environment only

**Invalid values:**
- `staging` — Rejected with error
- `production` — Rejected with error
- Any other value — Rejected

### `-ConfirmReset` (Optional, Default: `$false`)
Confirmation flag to prevent accidental resets. 
- `$true` — Proceeds with reset
- `$false` or omitted — Cancels operation, returns `RESET_CANCELLED` status

## Usage

### Reset with confirmation (proceed with reset)
```powershell
& oracle-schema-reset.ps1 -Environment local -ConfirmReset
```

### Reset with explicit false (cancel reset)
```powershell
& oracle-schema-reset.ps1 -Environment local -ConfirmReset $false
# Output: RESET_CANCELLED
```

### Attempt non-dev environment (rejected)
```powershell
& oracle-schema-reset.ps1 -Environment staging -ConfirmReset
# ERROR: Schema reset only allowed in 'local' (dev) environment
# Exit code: 1
```

## Output Format

Returns JSON + markdown blocks with reset confirmation and final schema state.

### Success Response (Exit Code 0)
```json
{
  "Title": "Schema Reset",
  "Status": "SUCCESS",
  "Environment": "local",
  "TablesDropped": 7,
  "TablesRecreated": 0,
  "DateResetAt": "2026-07-09T14:30:00Z",
  "ResetReason": "Manual reset via oracle-schema-reset",
  "Details": {
    "DroppedTables": ["EMPLOYEES", "DEPARTMENTS", "JOBS", "LOCATIONS", "COUNTRIES", "REGIONS", "JOB_HISTORY"],
    "RecreatedTables": [],
    "SeedDataApplied": false,
    "InitScriptsApplied": 0
  }
}
```

### Cancelled Response (Exit Code 0)
```json
{
  "Title": "Schema Reset",
  "Status": "RESET_CANCELLED",
  "Environment": "local",
  "TablesDropped": 0,
  "TablesRecreated": 0,
  "DateResetAt": "2026-07-09T14:30:00Z",
  "ResetReason": "User cancelled - confirmation not provided",
  "Details": {
    "DroppedTables": [],
    "RecreatedTables": [],
    "SeedDataApplied": false,
    "InitScriptsApplied": 0
  }
}
```

### Error Response (Exit Code 1)
```json
{
  "Title": "Schema Reset",
  "Status": "ERROR",
  "Environment": "staging",
  "TablesDropped": 0,
  "TablesRecreated": 0,
  "DateResetAt": "2026-07-09T14:30:00Z",
  "ResetReason": "Error during reset operation",
  "Details": {
    "Error": "ERROR: Schema reset only allowed in 'local' (dev) environment. Environment 'staging' is NOT dev. Refusing to reset staging or production.",
    "ErrorContext": "RuntimeException"
  }
}
```

Also includes markdown summary table for easy reading.

## Exit Codes

- **0** — Success (schema reset or operation cancelled due to missing confirmation)
- **1** — Failure (non-dev environment attempt, error during reset, database connection error)

## Process

1. **Environment Check:** Verify `-Environment` is `"local"`. Reject staging/production immediately.
2. **Confirmation Check:** If `-ConfirmReset` is `$false` or omitted, cancel operation.
3. **Connect:** Establish database connection to local environment.
4. **Query Tables:** Get list of all user tables in schema.
5. **Drop Tables:** Execute `DROP TABLE table_name CASCADE CONSTRAINTS` for each table.
6. **Verify:** Confirm schema is empty (no user tables remaining).
7. **Format Output:** Return JSON + markdown confirmation + final schema state.
8. **Exit:** Exit code 0 (success) or 1 (failure).

## Dependencies

- `OracleConnection.psm1` — Database connection, environment config, query execution
- `SchemaInspector.psm1` — Table discovery, schema inspection
- `OutputFormatter.psm1` — JSON + markdown formatting

## Error Handling

Errors during reset operations:
- Logged with context (table name, error message)
- Partial reset continues (one table drop failure doesn't stop other drops)
- Final result reflects actual dropped tables and any errors encountered

Database connection errors:
- Caught, logged with error message
- Exit code 1 returned

Invalid table names:
- Validated with regex `^[A-Z0-9_]{1,30}$` before SQL interpolation
- Invalid names skipped with warning
- SQL injection prevented via validation before string interpolation

## Testing

Run Pester tests:
```powershell
Invoke-Pester -Path ".claude/skills/oracle-skills/tests/Tier2.SchemaReset.Tests.ps1" -Verbose
```

Test coverage includes:
- Parameter validation (environment, confirmation flag)
- Dev-only enforcement (staging/production rejection)
- Output format validation (JSON + markdown blocks, required fields)
- Exit codes (0 for success, 1 for failure)
- Security scenarios (non-dev rejection, confirmation cancellation)

## Warnings

**This is a high-risk operation:**
- **Permanent:** All dropped tables are gone. No recovery without backup.
- **Data Loss:** All data in dropped tables is lost.
- **Dev Only:** Only works in local (dev) environment for safety.
- **Requires Confirmation:** Explicit `-ConfirmReset` flag prevents accidental resets.
- **Audit Trail:** Reset events should be logged for compliance.

**Before running:**
1. Ensure you're targeting the `local` environment
2. Confirm no active development work depends on current schema
3. Provide `-ConfirmReset` flag explicitly

## Roadmap

Future enhancements (not Phase 2):
- Automatic backup before reset
- Snapshot comparison before/after
- Re-apply init scripts automatically
- Seed data restoration
- Dry-run mode (preview tables that would be dropped)

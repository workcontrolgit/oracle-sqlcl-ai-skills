# oracle-migration-status Skill

## Purpose

The `oracle-migration-status` skill queries an Oracle database migrations table and provides comprehensive schema version information for diagnostic and deployment verification purposes.

## Use Cases

- Pre-deployment verification: Check current schema version before applying migrations
- Migration health monitoring: Identify failed or pending migrations
- Deployment diagnostics: Include migration status in deployment health checks
- Infrastructure audits: Track schema versioning across environments

## Parameters

### Environment (mandatory)
- **Type:** String
- **Values:** `local`, `staging`, `production`
- **Description:** Target database environment for migration status check

### MigrationsTable (optional)
- **Type:** String
- **Default:** `SCHEMA_MIGRATIONS`
- **Description:** Name of the migrations tracking table in Oracle schema

## Output Format

The skill produces output in two formats for different audiences:

### JSON Block (Pipeline Parsing)
```json
{
  "Status": "PASS|FAIL|WARNING|ERROR",
  "Message": "Human-readable status message",
  "CurrentVersion": "latest_migration_name",
  "TotalMigrations": 42,
  "AppliedMigrations": 40,
  "FailedMigrations": 2,
  "PendingMigrations": 0,
  "LastAppliedDate": "2026-07-09 14:30:00",
  "FailedMigrationsList": ["001_fix_table.sql", "002_add_index.sql"],
  "PendingMigrationsList": []
}
```

### Markdown Block (Human Readability)
```markdown
- **Status**: PASS|FAIL
- **Message**: Status explanation
- **CurrentVersion**: Latest applied migration
- **TotalMigrations**: Total count
- **AppliedMigrations**: Successfully applied count
- **FailedMigrations**: Failed count
- **PendingMigrations**: Unapplied count
- **LastAppliedDate**: Timestamp of last migration

## Items

| Name | Status | AppliedDate |
|------|--------|-------------|
| 001_initial_schema.sql | SUCCESS | 2026-07-01 10:00:00 |
| 002_add_users_table.sql | SUCCESS | 2026-07-02 11:30:00 |
```

## Exit Codes

- `0`: All migrations applied successfully (Status=PASS)
- `1`: Migration failures detected or query errors (Status=FAIL or ERROR)

## Dependencies

- **OracleConnection.psm1**: Handles database connectivity and SQL execution
- **SchemaInspector.psm1**: Validates and inspects schema metadata
- **OutputFormatter.psm1**: Formats output for JSON + markdown display

## Examples

### Check Local Environment
```powershell
& oracle-migration-status.ps1 -Environment local
```

### Check Production with Custom Table
```powershell
& oracle-migration-status.ps1 -Environment production -MigrationsTable CUSTOM_MIGRATIONS_TABLE
```

### Capture Output for Automation
```powershell
$output = & oracle-migration-status.ps1 -Environment staging -ErrorAction SilentlyContinue
$exitCode = $LASTEXITCODE

# Parse JSON from output
$jsonBlock = $output -split '```' | Where-Object { $_ -match 'json' } | Select-Object -Skip 1 | Select-Object -First 1
$status = $jsonBlock | ConvertFrom-Json
```

## Integration Points

- **oracle-pre-deploy-check**: Calls this skill to verify schema readiness
- **oracle-migration-diff**: Uses status to identify applied vs pending migrations
- **deployment-pipeline**: Exit code used for deployment gating decisions

## Schema Requirements

The migrations table must contain these columns:

- `migration_name` (VARCHAR): Unique name of migration
- `migration_status` (VARCHAR): Status indicator (SUCCESS, FAILED, PENDING, etc.)
- `applied_at` (TIMESTAMP): When migration was applied/attempted

## Behavior

1. **Validates** the environment parameter against allowed values
2. **Checks** if migrations table exists in schema
3. **Queries** migration records from the table
4. **Analyzes** results:
   - Counts total, applied, failed, and pending migrations
   - Identifies current schema version (latest successful)
   - Detects last applied date
5. **Formats** output with JSON (machine-readable) + markdown (human-readable)
6. **Returns** exit code: 0 if success, 1 if failures/errors

## Error Handling

- Missing migrations table: Returns WARNING status, exit code 1
- Database connection error: Returns ERROR status with exception details, exit code 1
- Invalid environment parameter: Throws validation error immediately
- Missing environment variables: Throws error from OracleConnection module

## Testing

Run the test suite:
```powershell
Invoke-Pester '.\.claude\skills\oracle-skills\tests\Tier2.Migration.Tests.ps1'
```

Tests verify:
- Parameter validation for environment
- Output format (JSON + markdown blocks present)
- Migration status detection
- Exit code behavior
- Support for all environments (local, staging, production)

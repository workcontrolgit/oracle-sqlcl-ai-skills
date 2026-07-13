# oracle-migration-validate Skill

## Purpose

The `oracle-migration-validate` skill validates that all expected migrations have been applied to the target Oracle database environment. It provides pipeline-ready JSON output for automation and human-readable markdown for manual verification.

## Use Cases

- Pre-deployment validation: Ensure all required migrations are applied before deploying code
- Deployment gating: Use exit code in CI/CD pipelines to gate deployments on migration status
- Environment parity checks: Verify expected migrations across local, staging, and production
- Migration troubleshooting: Identify missing or unexpected migrations in the database

## Parameters

### Environment (mandatory)
- **Type:** String
- **Values:** `local`, `staging`, `production`
- **Description:** Target database environment for migration validation

### ExpectedMigrations (mandatory)
- **Type:** String or Array
- **Format:** Array: `@("0001_init", "0002_users")` or CSV: `"0001_init,0002_users"`
- **Description:** List of migration names expected to be applied
- **Examples:**
  - Array: `@("0001_init_schema", "0002_add_users_table", "0003_create_indices")`
  - CSV string: `"0001_init_schema,0002_add_users_table,0003_create_indices"`
  - Single: `"0001_init_schema"`

### MigrationsTable (optional)
- **Type:** String
- **Default:** `SCHEMA_MIGRATIONS`
- **Pattern:** Must match `[A-Z0-9_]{1,30}` for Oracle naming conventions
- **Description:** Name of the migrations tracking table in Oracle schema

## Output Format

The skill produces two output blocks for different audiences:

### JSON Block (Pipeline Parsing)
```json
{
  "Status": "VALID|INVALID|ERROR",
  "Environment": "local",
  "MigrationsTable": "SCHEMA_MIGRATIONS",
  "Summary": {
    "Expected": 5,
    "Applied": 4,
    "Missing": 1,
    "Extra": 0
  },
  "Migrations": [
    {
      "Name": "0001_init_schema",
      "Status": "Applied",
      "AppliedAt": "2026-07-09 10:15:30"
    },
    {
      "Name": "0002_add_users",
      "Status": "Missing"
    }
  ]
}
```

### Markdown Block (Human Readability)
```markdown
## Migration Validation Result

- **Status**: VALID
- **Environment**: local
- **Migrations Table**: SCHEMA_MIGRATIONS

## Summary

- **Expected**: 5
- **Applied**: 5
- **Missing**: 0
- **Extra**: 0

**Result**: All 5 migrations applied successfully!

## Migrations

| Migration | Status | AppliedAt |
|-----------|--------|-----------|
| 0001_init_schema | ✓ Applied | 2026-07-09 10:15:30 |
| 0002_add_users | ✓ Applied | 2026-07-09 10:16:00 |
```

## Exit Codes

- **0**: Validation passed - all expected migrations applied (Status=VALID)
- **1**: Validation failed - missing migrations or error occurred (Status=INVALID or ERROR)

## Status Values

- **VALID**: All expected migrations have been applied to the database
- **INVALID**: One or more expected migrations are missing from the database
- **ERROR**: An error occurred during validation (table not found, connection failed, etc.)

## Dependencies

- **OracleConnection.psm1**: Handles database connectivity and SQL execution
- **SchemaInspector.psm1**: Validates schema and checks table existence
- **OutputFormatter.psm1**: Formats JSON and markdown output blocks

## Examples

### Check Local Environment with Array Input
```powershell
& oracle-migration-validate.ps1 -Environment local -ExpectedMigrations @("0001_init", "0002_users", "0003_roles")
```

### Check Production with CSV String Input
```powershell
& oracle-migration-validate.ps1 -Environment production -ExpectedMigrations "0001_init,0002_users,0003_roles"
```

### Check with Custom Migrations Table
```powershell
& oracle-migration-validate.ps1 -Environment staging -ExpectedMigrations @("v1_initial", "v2_schema") -MigrationsTable "CUSTOM_MIGRATIONS_TRACKER"
```

### Use in CI/CD Pipeline (Bash)
```bash
powershell -Command "& '.\.claude\skills\oracle-skills\tier3\oracle-migration-validate.ps1' -Environment production -ExpectedMigrations '0001_init,0002_users'"
if [ $? -eq 0 ]; then
  echo "All migrations validated. Proceeding with deployment..."
else
  echo "Migration validation failed. Deployment blocked."
  exit 1
fi
```

### Capture and Parse JSON Output
```powershell
$output = & oracle-migration-validate.ps1 -Environment staging -ExpectedMigrations @("0001_init", "0002_users") -ErrorAction SilentlyContinue
$exitCode = $LASTEXITCODE

# Extract JSON from output (between ```json and ```)
$jsonMatch = $output -match '```json([\s\S]*?)```'
if ($jsonMatch) {
  $jsonBlock = $Matches[1].Trim()
  $result = $jsonBlock | ConvertFrom-Json
  Write-Host "Status: $($result.Status)"
  Write-Host "Applied: $($result.Summary.Applied)/$($result.Summary.Expected)"
}
```

## Behavior

1. **Validates** the environment parameter against allowed values (local, staging, production)
2. **Parses** expected migrations from array or CSV string format
3. **Checks** if migrations table exists in the schema
4. **Queries** applied migration records from the database
5. **Compares** expected migrations against applied:
   - Applied: Migration names found in database, with timestamp
   - Missing: Migration names not found in database
   - Extra: Migration names in database but not in expected list (informational)
6. **Calculates** summary: counts of expected, applied, missing, and extra migrations
7. **Formats** output with JSON (machine-readable) + markdown (human-readable)
8. **Returns** exit code: 0 for VALID, 1 for INVALID/ERROR

## Migration Matching

The skill uses flexible matching when comparing expected vs. applied migrations:

- **Exact match**: "0001_init" matches "0001_init"
- **Prefix match**: "0001" matches "0001_init_schema" (applied migration can have more details)
- **Case-insensitive for table names**: Uses Oracle standard uppercase naming

## Error Handling

| Scenario | Status | Exit Code | Message |
|----------|--------|-----------|---------|
| All migrations applied | VALID | 0 | "All X migrations applied successfully!" |
| Some migrations missing | INVALID | 1 | "X/Y migrations missing" |
| Migrations table not found | ERROR | 1 | "Migrations table not found or query failed" |
| Database connection error | ERROR | 1 | Exception details with error message |
| Invalid environment parameter | N/A | Exception | Parameter validation error |
| Invalid table name parameter | N/A | Exception | Table name validation error (regex) |
| Empty expected migrations | N/A | Exception | "No expected migrations specified" |

## Testing

Run the test suite:
```powershell
Invoke-Pester '.\.claude\skills\oracle-skills\tier3\oracle-migration-validate.Tests.ps1'
```

Tests verify:
- Parameter validation (mandatory params, valid environments)
- Migration input parsing (array, CSV string, single item)
- Custom migrations table support
- Output format (JSON + markdown code blocks)
- Status field values (VALID, INVALID, ERROR)
- Summary calculation (Expected, Applied, Missing, Extra)
- Exit codes (0 for VALID, 1 for INVALID/ERROR)
- Error handling (missing table, connection failures)
- Markdown table formatting (special char escaping)

## Integration Points

- **Pre-deployment pipeline**: Call before deploying application code to verify database readiness
- **Monitoring dashboards**: Parse JSON Status field to track validation across environments
- **Automated remediation**: Use INVALID status to trigger migration application workflow
- **Compliance audits**: Track which migrations have been applied to each environment

## Schema Requirements

The migrations table must contain these columns:
- `migration_name` (VARCHAR/STRING): Unique identifier for migration
- `applied_at` (TIMESTAMP/DATE): When the migration was applied

The table is queried with:
```sql
SELECT DISTINCT
    migration_name as Name,
    applied_at as AppliedAt
FROM SCHEMA_MIGRATIONS
WHERE migration_name IS NOT NULL
ORDER BY applied_at DESC
```

If columns have different names in your schema, create a view that maps to these standard names.

## Limitations

- Queries only applied migrations (not pending or failed migrations)
- Does not apply migrations or modify database state
- Does not validate migration content or dependencies
- Table name must follow Oracle naming constraints (alphanumeric + underscore, 1-30 chars)

## Future Enhancements

- Support for more complex migration matching patterns (regex)
- Validation of migration dependency chains
- Integration with migration application tools
- Custom migration status patterns beyond "applied"

# oracle-schema-conflict-detect

## Purpose

Detects schema conflicts and drift in Oracle databases by comparing the actual schema against the expected schema state. Identifies:

- **Drift**: Objects that exist in the actual schema but are not in the expected state (manual changes outside migrations)
- **Missing**: Objects that should exist according to migrations but are missing from the actual schema
- **Unexpected**: Objects that exist but shouldn't (for future enhancement)

This skill helps maintain schema consistency and detect unauthorized or accidental schema modifications.

## Parameters

### -Environment (Mandatory)

The target environment: `local`, `staging`, or `production`

### -MigrationsTable (Optional)

Name of the migrations tracking table. Default: `SCHEMA_MIGRATIONS`

Must be 1-30 alphanumeric characters and underscores only (validated to prevent SQL injection).

## Output Format

### JSON Output

```json
{
  "Title": "Schema Conflict Detection",
  "Status": "PASS" | "CONFLICTS_DETECTED",
  "Environment": "local",
  "CurrentVersion": "V202501020130",
  "TablesAnalyzed": 5,
  "DriftDetected": 2,
  "MissingObjects": 1,
  "UnexpectedObjects": 0,
  "Details": {
    "Drift": [
      { "Type": "COLUMN", "Table": "USERS", "Name": "TEMP_FIELD", "Status": "Extra in actual" },
      { "Type": "CONSTRAINT", "Table": "USERS", "Name": "CK_USERS_STATUS", "Status": "Extra in actual" }
    ],
    "Missing": [
      { "Type": "TABLE", "Name": "AUDIT_LOG", "Status": "Missing from actual" }
    ]
  }
}
```

### Markdown Output

A human-readable summary table showing:
- Status (PASS or CONFLICTS_DETECTED)
- Environment
- Current version
- Counts of conflicts by type
- Detailed conflict list (if applicable)

## Exit Codes

- **0**: Success (no conflicts detected)
- **1**: Conflicts detected or error occurred

## Usage Examples

### Basic usage - check local environment

```powershell
& ./.claude/skills/oracle-skills/tier2/oracle-schema-conflict-detect.ps1 -Environment local
```

### Custom migrations table

```powershell
& ./.claude/skills/oracle-skills/tier2/oracle-schema-conflict-detect.ps1 -Environment production -MigrationsTable MIGRATION_HISTORY
```

### Check staging environment

```powershell
& ./.claude/skills/oracle-skills/tier2/oracle-schema-conflict-detect.ps1 -Environment staging
```

## Dependencies

- **OracleConnection.psm1**: Database connection and query execution
- **SchemaInspector.psm1**: Schema metadata queries (tables, columns, constraints)
- **OutputFormatter.psm1**: JSON and markdown output formatting

## How It Works

1. **Load Environment Config**: Retrieves database connection settings
2. **Get Current Schema**: Queries actual schema (tables, columns, constraints)
3. **Get Expected Schema**: Defines baseline expected schema state (HR schema by default)
4. **Compare Schemas**:
   - Identifies objects in actual but not expected (drift)
   - Identifies objects in expected but not actual (missing)
5. **Categorize Conflicts**: Groups by type (TABLE, COLUMN, CONSTRAINT)
6. **Format Output**: Creates JSON (machine-readable) and markdown (human-readable) reports

## Difference from oracle-migration-diff

| Aspect | oracle-migration-diff | oracle-schema-conflict-detect |
|--------|---------------------|-----------------------|
| **Purpose** | Compare expected vs. actual schema | Detect drift and conflicts |
| **Focus** | Missing objects | Drift (extra objects) + missing objects |
| **Use Case** | Verify migrations applied correctly | Detect unauthorized schema changes |
| **Status** | PASS / DIFFERENCES_FOUND | PASS / CONFLICTS_DETECTED |

## Error Handling

- Validates migrations table name with regex `^[A-Z0-9_]{1,30}$` to prevent SQL injection
- Gracefully handles missing migrations table
- Handles empty schemas
- Propagates errors with descriptive messages
- Returns exit code 1 on any error

## Security Considerations

- Table names validated before SQL interpolation
- Uses parameterized queries where possible
- Environment variables expanded only from config
- No hardcoded credentials
- Error messages don't expose sensitive data

## Testing

Comprehensive Pester v3 tests cover:
- Parameter validation (-Environment required, invalid values rejected)
- Environment support (local, staging, production)
- Conflict detection (drift, missing objects)
- Output format (JSON + markdown)
- Exit codes (0 success, 1 conflicts)
- Edge cases (empty schema, no migrations, custom table names)
- Security (SQL injection prevention)

Run tests with:
```powershell
Invoke-Pester -Path ./.claude/skills/oracle-skills/tests/Tier2.SchemaConflict.Tests.ps1
```

## Known Limitations (Phase 2)

- Expected schema currently uses HR baseline (hardcoded)
- Future enhancement: Make expected schema migration-driven via metadata analysis
- Future enhancement: Support for detecting unexpected tables/columns
- Future enhancement: Custom conflict resolution rules

## Notes

- Works with PowerShell 5.1+
- Uses Pester v3 syntax for tests
- No external dependencies beyond PowerShell core + Pester
- Markdown output escapes special characters (pipes, backslashes) for proper formatting

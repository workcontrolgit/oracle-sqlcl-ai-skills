# oracle-migration-diff Skill

## Purpose

Compares the current Oracle database schema against the expected schema state from the latest applied migration. Identifies schema differences including missing tables, columns, and constraints to validate migration state.

## Parameters

### -Environment (Mandatory)

Target environment for schema comparison.

- **Type:** string
- **Valid values:** `local`, `staging`, `production`
- **Example:** `-Environment local`

### -MigrationsTable (Optional)

Name of the migrations table to query for current version.

- **Type:** string
- **Default:** `SCHEMA_MIGRATIONS`
- **Validation:** Must be 1-30 alphanumeric characters and underscores only (SQL injection prevention)
- **Example:** `-MigrationsTable CUSTOM_MIGRATIONS`

## Output Format

### JSON Block
Contains structured diff report:
```json
{
  "Title": "Schema Migration Diff",
  "Status": "PASS or DIFFERENCES_FOUND",
  "Environment": "local",
  "CurrentVersion": "V202501020130",
  "TablesAnalyzed": 6,
  "MissingTables": 0,
  "MissingColumns": 2,
  "MissingConstraints": 1,
  "UnexpectedTables": 0,
  "Details": {
    "MissingColumns": [
      { "Table": "USERS", "Column": "CREATED_AT", "Type": "DATE" }
    ],
    "MissingConstraints": [
      { "Table": "USERS", "Constraint": "PK_USERS", "Type": "PRIMARY_KEY" }
    ]
  }
}
```

### Markdown Block
Human-readable summary with:
- Comparison status and message
- Table analysis metrics
- Diff details (if any differences found)

## Exit Codes

- `0` - Success (schema matches expected state)
- `1` - Differences found or error occurred

## Usage Examples

### Basic Usage
```powershell
& oracle-migration-diff.ps1 -Environment local
```

### Custom Migrations Table
```powershell
& oracle-migration-diff.ps1 -Environment production -MigrationsTable MIGRATION_HISTORY
```

### Production Environment
```powershell
& oracle-migration-diff.ps1 -Environment production
```

## Logic

1. **Retrieve Current Schema**: Queries user_tables, user_tab_columns, and user_constraints
2. **Get Migration Version**: Queries migrations table for latest applied migration
3. **Compare Against Baseline**: Compares current schema against known expected state (HR schema tables: EMPLOYEES, DEPARTMENTS, JOBS, LOCATIONS, COUNTRIES, REGIONS)
4. **Identify Diffs**: Tracks missing tables, columns, and constraints
5. **Output Results**: Formats diff report as JSON + markdown

## Security

- **SQL Injection Prevention:** Table names validated with regex `^[A-Z0-9_]{1,30}$`
- **Quote Escaping:** Single quotes escaped as doubled quotes in SQL
- **Environment Variables:** No hardcoded credentials

## Dependencies

- `OracleConnection.psm1` - Manages environment config and query execution
- `SchemaInspector.psm1` - Queries schema metadata (tables, columns, constraints)
- `OutputFormatter.psm1` - Formats output as JSON + markdown

## Error Handling

- Gracefully handles missing migrations table (returns warning)
- Propagates schema query errors to caller
- Returns ERROR status with descriptive message on failure
- Wrapped in try-catch blocks throughout

## Testing

Tested with Pester v3 (PowerShell 5.1+) covering:
- Parameter validation and environments
- Schema comparison logic
- Output format (JSON + markdown)
- Exit codes
- Edge cases (custom tables, SQL injection attempts, missing tables)

## Implementation Notes

- Baseline schema is HR schema with standard tables and columns
- Can be enhanced to support custom migration metadata
- Future versions can track historical schema versions from migration logs

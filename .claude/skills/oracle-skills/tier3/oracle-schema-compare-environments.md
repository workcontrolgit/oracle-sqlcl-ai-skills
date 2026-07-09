# oracle-schema-compare-environments

## Purpose

Compares database schemas between two different environments (source vs. target) to identify schema differences. Useful for validating schema consistency across deployment environments and detecting unintended schema drift.

This skill helps ensure that databases in different environments (local, staging, production) maintain consistent schemas before deploying applications.

## Parameters

### -SourceEnvironment (Mandatory)

The source environment: `local`, `staging`, or `production`

Must differ from the target environment.

### -TargetEnvironment (Mandatory)

The target environment: `local`, `staging`, or `production`

Must differ from the source environment.

### -ComparisonType (Optional, default: "full")

Scope of comparison:

- `full`: Compare all objects (tables, columns, constraints, indexes)
- `subset`: Compare tables and columns only (faster for large schemas)

## Output Format

### JSON Output

```json
{
  "Status": "SCHEMAS_MATCH" | "SCHEMAS_DIFFER" | "ERROR",
  "SourceEnvironment": "local",
  "TargetEnvironment": "staging",
  "ComparisonType": "full",
  "Summary": {
    "SourceTables": 12,
    "TargetTables": 11,
    "TablesMatch": 10,
    "MissingInTarget": 2,
    "ExtraInTarget": 1,
    "ColumnDifferences": 0,
    "ConstraintDifferences": 0
  },
  "Diffs": [
    {
      "Table": "CUSTOMERS",
      "Type": "MissingInTarget",
      "Details": "Table exists in source but not in target"
    },
    {
      "Table": "ORDERS",
      "Type": "ColumnMissing",
      "Details": "Column ORDER_DATE: exists in source but not in target"
    }
  ]
}
```

### Markdown Output

A human-readable summary table showing:
- Source and target environments
- Table counts and match statistics
- Status (SCHEMAS_MATCH or SCHEMAS_DIFFER)
- Detailed diff list (if applicable)

## Exit Codes

- **0**: Schemas match
- **1**: Schemas differ or error occurred

## Usage Examples

### Compare local and staging schemas

```powershell
& ./.claude/skills/oracle-skills/tier3/oracle-schema-compare-environments.ps1 `
  -SourceEnvironment local `
  -TargetEnvironment staging
```

### Compare with subset comparison (faster)

```powershell
& ./.claude/skills/oracle-skills/tier3/oracle-schema-compare-environments.ps1 `
  -SourceEnvironment staging `
  -TargetEnvironment production `
  -ComparisonType subset
```

### Full comparison between staging and production

```powershell
& ./.claude/skills/oracle-skills/tier3/oracle-schema-compare-environments.ps1 `
  -SourceEnvironment staging `
  -TargetEnvironment production `
  -ComparisonType full
```

## Dependencies

- **OracleConnection.psm1**: Database connection and query execution
- **SchemaInspector.psm1**: Schema metadata queries (tables, columns, constraints)
- **OutputFormatter.psm1**: JSON and markdown output formatting

## How It Works

1. **Validate Parameters**: Ensures source and target environments differ
2. **Retrieve Source Schema**: Queries source environment for tables, columns, constraints
3. **Retrieve Target Schema**: Queries target environment for tables, columns, constraints
4. **Compare Schemas**:
   - Identifies tables missing in target
   - Identifies extra tables in target
   - Identifies column differences for matching tables
   - (Full mode) Identifies constraint differences
5. **Categorize Differences**: Groups diffs by type (MissingInTarget, ExtraInTarget, ColumnMissing, ColumnExtra, etc.)
6. **Format Output**: Creates JSON (machine-readable) and markdown (human-readable) reports

## Diff Types

| Type | Meaning |
|------|---------|
| MissingInTarget | Table exists in source but not in target |
| ExtraInTarget | Table exists in target but not in source |
| ColumnMissing | Column exists in source table but not in target |
| ColumnExtra | Column exists in target table but not in source |
| ConstraintMissing | Constraint exists in source but not in target (full mode) |
| ConstraintExtra | Constraint exists in target but not in source (full mode) |

## Error Handling

- Validates that source and target environments are different
- Validates all parameters against allowed values
- Gracefully handles missing tables or empty schemas
- Propagates query errors with descriptive messages
- Returns Status: ERROR on any failure
- Returns exit code 1 on any error

## Security Considerations

- Uses parameterized queries via SchemaInspector module
- Table names validated before SQL interpolation
- Environment variables expanded only from config (OracleConnection module)
- No hardcoded credentials
- Markdown output escapes special characters (pipes, backslashes) for proper formatting

## Testing

Comprehensive Pester v3 tests cover:
- Parameter validation (required params, invalid values, identical environments)
- Schema comparison logic (diff detection, categorization)
- Output format (JSON + markdown structure)
- Exit codes (0 for match, 1 for differ/error)
- Error handling (invalid environments, connection failures)
- ComparisonType handling (full vs. subset modes)

Run tests with:
```powershell
Invoke-Pester -Path ./.claude/skills/oracle-skills/tier3/oracle-schema-compare-environments.Tests.ps1
```

## Known Limitations

- Compares by table/column names only (not by column types, constraints, or indexes in basic comparison)
- Full mode comparison includes constraint names but not constraint definitions
- Does not track schema versioning (external versioning tools recommended)

## Related Skills

- **oracle-schema-conflict-detect**: Detects drift vs. expected schema state
- **oracle-migration-diff**: Compares migrations against schema
- **oracle-migration-status**: Tracks migration application status

## Notes

- Works with PowerShell 5.1+
- Uses Pester v3 syntax for tests
- No external dependencies beyond PowerShell core + Pester
- Processes tables sequentially; performance scales with schema size

# oracle-schema-drift-detect

**Tier:** 3 (CI/CD automation)
**Purpose:** Detect schema objects that were manually created or altered outside of migrations (schema drift). Designed for CI/CD pipelines to catch drift between expected baseline and actual database state.

## Parameters

| Parameter | Required | Values | Default | Description |
|-----------|----------|--------|---------|-------------|
| `-Environment` | Yes | `local`, `staging`, `production` | — | Target Oracle environment to inspect |
| `-BaselineVersion` | No | Any string | `current` | Migration version used as baseline reference |
| `-OutputFormat` | No | `Full`, `Summary` | `Full` | Controls detail level of output |

## Status Values

| Status | Meaning | Exit Code |
|--------|---------|-----------|
| `NO_DRIFT` | Actual schema matches the known HR baseline exactly | 0 |
| `DRIFT_DETECTED` | Extra or missing objects found relative to baseline | 1 |
| `ERROR` | Connection failure or query error | 1 |

## Output Format

Produces both JSON and markdown code blocks:

```json
{
  "Status": "DRIFT_DETECTED",
  "Environment": "staging",
  "BaselineVersion": "current",
  "DriftObjects": [
    { "Type": "TABLE", "Name": "TEMP_AUDIT", "DriftType": "Extra" },
    { "Type": "COLUMN", "Table": "EMPLOYEES", "Name": "MANUAL_COL", "DriftType": "Extra" }
  ],
  "MissingObjects": [],
  "Summary": { "Total": 2, "DriftCount": 2, "MissingCount": 0 }
}
```

- **DriftObjects** — tables/columns present in the actual DB but NOT in the baseline (manually created)
- **MissingObjects** — tables/columns expected by the baseline but absent from the actual DB
- **Summary.DriftCount** — count of extra (drift) objects
- **Summary.MissingCount** — count of missing objects

## Baseline Definition

The skill uses the Oracle HR schema as the known baseline:

**Tables:** EMPLOYEES, DEPARTMENTS, JOBS, JOB_HISTORY, LOCATIONS, COUNTRIES, REGIONS

Key columns per table are also tracked. Any table or column present in the live DB that is not part of this baseline is flagged as drift (`DriftType: "Extra"`). Any expected table or column absent from the live DB is flagged as missing (`DriftType: "Missing"`).

## Usage Examples

```powershell
# Basic drift check on local environment
& oracle-schema-drift-detect.ps1 -Environment local

# Staging drift check with summary output only
& oracle-schema-drift-detect.ps1 -Environment staging -OutputFormat Summary

# Production check with specific baseline version label
& oracle-schema-drift-detect.ps1 -Environment production -BaselineVersion "v2.3.0"
```

## CI/CD Pipeline Integration

```yaml
- name: Schema Drift Detection
  run: |
    pwsh -File oracle-schema-drift-detect.ps1 -Environment staging
  # Exit code 1 blocks the pipeline on drift or error
```

## Module Dependencies

- `OracleConnection.psm1` — environment config and query execution
- `SchemaInspector.psm1` — `Get-TableList`, `Get-TableColumns`, `Get-TableConstraints`
- `OutputFormatter.psm1` — `ConvertTo-DiagnosticJson`, `ConvertTo-MarkdownTable`

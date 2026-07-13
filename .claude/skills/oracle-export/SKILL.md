---
name: oracle-export
description: Use when exporting Oracle query results to CSV or Excel file - use SQLcl SPOOL with SQLFORMAT csv or xlsx
---

# Oracle Export

## Overview

Export Oracle query results to CSV or Excel files using SQLcl's built-in format commands. This skill uses SQLcl directly via Bash (not MCP tools) because it requires file I/O.

**Core principle:** Use `SET SQLFORMAT` + `SPOOL` to write real query results to disk.

## When to Use

- User asks to export data to CSV
- User asks to export data to Excel
- User wants to download or save query results to a file
- User needs data for reporting, sharing, or import into another tool

## SQLcl Location

```
C:\Users\Fuji Nguyen\.vscode\extensions\oracle.sql-developer-26.2.0-win32-x64\dbtools\sqlcl\bin\sql.exe
```

## Export to CSV

```powershell
$SQLCL = "C:\Users\Fuji Nguyen\.vscode\extensions\oracle.sql-developer-26.2.0-win32-x64\dbtools\sqlcl\bin\sql.exe"
$outputFile = "C:\exports\departments.csv"

@"
SET SQLFORMAT csv
SET HEADING ON
SET FEEDBACK OFF
SPOOL $outputFile
SELECT * FROM departments ORDER BY department_id;
SPOOL OFF
EXIT;
"@ | & $SQLCL -s hr/HrUser_2026@//localhost:1521/XEPDB1
```

## Export to Excel (.xlsx)

```powershell
$SQLCL = "C:\Users\Fuji Nguyen\.vscode\extensions\oracle.sql-developer-26.2.0-win32-x64\dbtools\sqlcl\bin\sql.exe"
$outputFile = "C:\exports\departments.xlsx"

@"
SET SQLFORMAT xlsx
SET HEADING ON
SET FEEDBACK OFF
SPOOL $outputFile
SELECT * FROM departments ORDER BY department_id;
SPOOL OFF
EXIT;
"@ | & $SQLCL -s hr/HrUser_2026@//localhost:1521/XEPDB1
```

## Export with Custom Columns and Filter

```powershell
$SQLCL = "C:\Users\Fuji Nguyen\.vscode\extensions\oracle.sql-developer-26.2.0-win32-x64\dbtools\sqlcl\bin\sql.exe"
$outputFile = "C:\exports\employees.csv"

@"
SET SQLFORMAT csv
SET HEADING ON
SET FEEDBACK OFF
SPOOL $outputFile
SELECT e.employee_id, e.first_name, e.last_name, e.salary, d.department_name
FROM employees e
JOIN departments d ON e.department_id = d.department_id
ORDER BY d.department_name, e.last_name;
SPOOL OFF
EXIT;
"@ | & $SQLCL -s hr/HrUser_2026@//localhost:1521/XEPDB1
```

## Implementation Steps

1. **Ask user for:** output format (csv/xlsx), output file path, and SQL query (or table name)
2. **Create output directory** if it doesn't exist
3. **Run SQLcl** with `SET SQLFORMAT csv` or `SET SQLFORMAT xlsx` and `SPOOL <path>`
4. **Confirm** file was created and show row count

## Format Options

| Format | Command | Notes |
|--------|---------|-------|
| CSV | `SET SQLFORMAT csv` | Comma-separated, headers included, opens in Excel |
| Excel | `SET SQLFORMAT xlsx` | Native .xlsx file, best for Excel users |
| JSON | `SET SQLFORMAT json` | For API/developer use |
| Fixed | `SET SQLFORMAT default` | Padded columns, human-readable |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Output directory doesn't exist | Create dir before running SPOOL |
| SPOOL path has spaces | Wrap path in double quotes: `SPOOL "C:\My Exports\file.csv"` |
| SET FEEDBACK ON left on | Use `SET FEEDBACK OFF` to keep file clean of row count messages |
| Forgot SPOOL OFF | Always end with `SPOOL OFF` or file may be incomplete |

## Why Not MCP?

The SQLcl MCP `run-sql` tool returns results to Claude — it cannot write to files on disk. Use this skill (Bash → SQLcl) whenever the output needs to be saved as a file.

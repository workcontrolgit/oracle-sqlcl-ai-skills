---
name: oracle-table-schema
description: Use when querying Oracle table structure, columns, data types, or constraints - execute DESC and column metadata queries via SQLcl
---

# Oracle Table Schema

## Overview

Get detailed schema information for specific Oracle tables including columns, data types, nullability, and constraints using SQLcl queries instead of MCP tools.

**Core principle:** Use SQLcl DESC command + metadata queries for schema exploration, never assume structure.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks for table structure (DESC EMPLOYEES)
- User requests column information (what columns exist, what are their types)
- User needs to understand table constraints (nullable columns, default values)
- User wants column details (ALL_TAB_COLUMNS metadata)
- You're about to describe a table structure from knowledge instead of querying

**When NOT to use:**
- Searching multiple tables by pattern → use oracle-search-tables
- Finding columns across all tables → use oracle-search-columns
- Getting relationships between tables → use oracle-table-relationships

## SQLcl Query Patterns

### Quick Table Structure (DESC)

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200

DESC EMPLOYEES;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Detailed Column Information

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN column_name FORMAT A30
COLUMN data_type FORMAT A20
COLUMN nullable FORMAT A10

SELECT 
  column_name, 
  data_type, 
  nullable,
  data_length,
  data_precision
FROM all_tab_columns
WHERE table_name = 'EMPLOYEES'
ORDER BY column_id;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Table Comments and Column Comments

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN column_name FORMAT A25
COLUMN comments FORMAT A40

SELECT 
  column_name,
  comments
FROM all_col_comments
WHERE table_name = 'EMPLOYEES'
ORDER BY column_id;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

## Implementation Steps

1. **User asks for table structure**
2. **Choose query type:**
   - Quick overview → DESC command (simplest)
   - Full column details → all_tab_columns query
   - Column comments → all_col_comments query
3. **Format with SET commands** (HEADING ON, FEEDBACK ON, PAGESIZE 200, LINESIZE 200)
4. **Execute via SQLcl**
5. **Return actual results unchanged**

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| "The EMPLOYEES table has..." (describing from knowledge) | Execute DESC EMPLOYEES first |
| Skipping all_tab_columns for detailed info | Use all_tab_columns for nullability, length, precision |
| Assuming column comments exist | Query ALL_COL_COMMENTS - results may be empty |
| Not formatting output properly | Always use SET HEADING ON, SET FEEDBACK ON |

## Red Flags - STOP and Query Instead

- "I know the table structure..."
- "The EMPLOYEES table probably has..."
- "Based on typical HR schemas..."
- "It likely has EMPLOYEE_ID, FIRST_NAME..."

**All of these mean: Execute DESC. Don't synthesize.**

## Example: Show EMPLOYEES Table Structure

User: "What's the EMPLOYEES table structure?"

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200

DESC EMPLOYEES;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

Expected output showing columns, nullability, data types.

If more detail needed:

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN column_name FORMAT A20
COLUMN data_type FORMAT A15
COLUMN nullable FORMAT A10

SELECT column_name, data_type, nullable
FROM all_tab_columns
WHERE table_name = 'EMPLOYEES'
ORDER BY column_id;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

## Configuration

**SQLcl connection:** `sql hr@//localhost:1521/XEPDB1`

**SET commands explained:**
- `SET HEADING ON` - Display column headers
- `SET FEEDBACK ON` - Show row counts
- `SET PAGESIZE 200` - Results per page
- `SET LINESIZE 200` - Max line width
- `COLUMN format` - Control column widths for readability

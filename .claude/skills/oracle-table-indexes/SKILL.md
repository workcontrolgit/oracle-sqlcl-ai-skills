---
name: oracle-table-indexes
description: Use when examining Oracle table indexes, understanding query optimization, finding performance improvement opportunities
---

# Oracle Table Indexes

## Overview

Get all indexes defined on Oracle tables using SQLcl metadata queries to understand performance optimization and query execution paths.

**Core principle:** Query USER_INDEXES and USER_IND_COLUMNS to discover index structure, never assume which columns are indexed.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks "what indexes exist on EMPLOYEES?"
- User wants to understand query performance
- User needs to find indexed columns
- User wants to see unique vs non-unique indexes
- You're tempted to guess which columns are indexed

**When NOT to use:**
- Getting full table schema → use oracle-table-schema
- Understanding constraints → use oracle-table-constraints
- Finding relationships → use oracle-table-relationships

## SQLcl Query Patterns

### All Indexes on Table

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN index_name FORMAT A30
COLUMN uniqueness FORMAT A15
COLUMN table_name FORMAT A25

SELECT index_name, uniqueness, table_name
FROM user_indexes
WHERE table_name = 'EMPLOYEES'
ORDER BY index_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Index Columns with Position

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN index_name FORMAT A30
COLUMN column_name FORMAT A25
COLUMN column_position FORMAT 99

SELECT ui.index_name, uic.column_name, uic.column_position
FROM user_indexes ui
JOIN user_ind_columns uic ON ui.index_name = uic.index_name
WHERE ui.table_name = 'EMPLOYEES'
ORDER BY ui.index_name, uic.column_position;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Unique vs Non-Unique Indexes

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN index_name FORMAT A30
COLUMN uniqueness FORMAT A12
COLUMN column_list FORMAT A50

SELECT ui.index_name, ui.uniqueness,
       LISTAGG(uic.column_name, ', ') WITHIN GROUP (ORDER BY uic.column_position) AS column_list
FROM user_indexes ui
LEFT JOIN user_ind_columns uic ON ui.index_name = uic.index_name
WHERE ui.table_name = 'EMPLOYEES'
GROUP BY ui.index_name, ui.uniqueness
ORDER BY ui.index_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Function-Based Indexes

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN index_name FORMAT A30
COLUMN column_expression FORMAT A50

SELECT index_name, column_expression
FROM user_ind_expressions
WHERE table_name = 'EMPLOYEES'
ORDER BY index_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

## Index Types

| Uniqueness | Meaning |
|-----------|---------|
| UNIQUE | Cannot contain duplicate values |
| NONUNIQUE | Can contain duplicate values |

## Implementation Steps

1. **User asks about indexes**
2. **Choose query type:**
   - All indexes → query user_indexes
   - With columns → JOIN user_ind_columns
   - Aggregate columns → Use LISTAGG for readability
   - Function-based → query user_ind_expressions
3. **Execute via SQLcl**
4. **Return actual results unchanged**

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| "EMPLOYEE_ID is probably indexed" | Query user_indexes first to confirm |
| Not showing column order | Join with user_ind_columns and show column_position |
| Assuming indexes exist | Query metadata - verify actual indexes |
| Missing composite indexes | Use LISTAGG to see multi-column indexes |

## Red Flags - STOP and Query Instead

- "There's probably an index on..."
- "It must be indexed for performance..."
- "Typically indexed on..."

**All of these mean: Query user_indexes first.**

## Example: Show All EMPLOYEES Indexes

User: "What indexes are on EMPLOYEES?"

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN index_name FORMAT A30
COLUMN column_name FORMAT A25

SELECT ui.index_name, uic.column_name
FROM user_indexes ui
JOIN user_ind_columns uic ON ui.index_name = uic.index_name
WHERE ui.table_name = 'EMPLOYEES'
ORDER BY ui.index_name, uic.column_position;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

Result: Shows all indexes and their columns on EMPLOYEES table

## Configuration

**SQLcl connection:** `sql hr@//localhost:1521/XEPDB1`

**Related Views:**
- user_indexes - Index definitions
- user_ind_columns - Index column mappings
- user_ind_expressions - Function-based index expressions
- all_indexes - Indexes across all schemas

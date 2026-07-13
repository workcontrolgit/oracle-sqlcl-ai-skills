---
name: oracle-table-relationships
description: Use when exploring Oracle table relationships, understanding foreign key dependencies, finding related tables
---

# Oracle Table Relationships

## Overview

Get all relationships between Oracle tables through foreign keys using SQLcl metadata queries to understand data dependencies and referential integrity.

**Core principle:** Query USER_CONSTRAINTS to find incoming and outgoing foreign key relationships, never assume table dependencies.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks "what tables reference DEPARTMENTS?"
- User wants to understand data dependencies
- User needs to find related tables through foreign keys
- User wants to trace data relationships
- You're tempted to guess which tables are related

**When NOT to use:**
- Getting full table constraints → use oracle-table-constraints
- Understanding primary keys only → use oracle-table-constraints
- Getting single table schema → use oracle-table-schema

## SQLcl Query Patterns

### Foreign Keys FROM Table

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN constraint_name FORMAT A30
COLUMN table_name FORMAT A25
COLUMN r_table_name FORMAT A25

SELECT constraint_name, table_name, r_table_name
FROM user_constraints
WHERE table_name = 'EMPLOYEES'
  AND constraint_type = 'R'
ORDER BY constraint_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Foreign Keys TO Table (Incoming References)

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN constraint_name FORMAT A30
COLUMN table_name FORMAT A25
COLUMN r_table_name FORMAT A25

SELECT constraint_name, table_name, r_table_name
FROM user_constraints
WHERE r_table_name = 'DEPARTMENTS'
  AND constraint_type = 'R'
ORDER BY constraint_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Detailed Foreign Key Relationships

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN fk_constraint FORMAT A30
COLUMN fk_table FORMAT A25
COLUMN fk_column FORMAT A25
COLUMN pk_column FORMAT A25

SELECT uc.constraint_name AS fk_constraint,
       uc.table_name AS fk_table,
       ucc.column_name AS fk_column,
       ucc2.column_name AS pk_column
FROM user_constraints uc
JOIN user_cons_columns ucc ON uc.constraint_name = ucc.constraint_name
JOIN user_constraints uc2 ON uc.r_constraint_name = uc2.constraint_name
JOIN user_cons_columns ucc2 ON uc2.constraint_name = ucc2.constraint_name
WHERE uc.table_name = 'EMPLOYEES'
  AND uc.constraint_type = 'R'
ORDER BY uc.constraint_name, ucc.position;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### All Related Tables (Both Directions)

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN relationship_type FORMAT A20
COLUMN related_table FORMAT A25
COLUMN constraint_name FORMAT A30

SELECT 'Parent Table' AS relationship_type, r_table_name AS related_table, constraint_name
FROM user_constraints
WHERE table_name = 'EMPLOYEES' AND constraint_type = 'R'
UNION ALL
SELECT 'Child Table' AS relationship_type, table_name AS related_table, constraint_name
FROM user_constraints
WHERE r_table_name = 'EMPLOYEES' AND constraint_type = 'R'
ORDER BY relationship_type, related_table;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

## Implementation Steps

1. **User asks about relationships**
2. **Choose query type:**
   - Outgoing FKs → WHERE table_name = 'TABLE' AND constraint_type = 'R'
   - Incoming FKs → WHERE r_table_name = 'TABLE' AND constraint_type = 'R'
   - Detailed columns → JOIN user_cons_columns
   - Both directions → UNION query
3. **Execute via SQLcl**
4. **Return actual results unchanged**

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| "EMPLOYEES references DEPARTMENTS" (guessing) | Query user_constraints first |
| Only checking one direction | Check both outgoing AND incoming FKs |
| Not showing column mappings | Join with user_cons_columns for details |
| Assuming relationships exist | Query metadata - verify actual FKs |

## Red Flags - STOP and Query Instead

- "It must reference..."
- "Probably related to..."
- "Typically points to..."

**All of these mean: Query foreign keys first.**

## Example: Show All Tables Related to EMPLOYEES

User: "What tables are related to EMPLOYEES?"

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN type FORMAT A15
COLUMN related_table FORMAT A25

SELECT 'References' AS type, r_table_name AS related_table
FROM user_constraints
WHERE table_name = 'EMPLOYEES' AND constraint_type = 'R'
UNION ALL
SELECT 'Referenced By' AS type, table_name AS related_table
FROM user_constraints
WHERE r_table_name = 'EMPLOYEES' AND constraint_type = 'R'
ORDER BY type, related_table;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

Result: Shows both parent and child tables related to EMPLOYEES

## Configuration

**SQLcl connection:** `sql hr@//localhost:1521/XEPDB1`

**Key Concepts:**
- Outgoing FK: table_name references r_table_name
- Incoming FK: r_table_name is referenced BY table_name
- Always check both directions for complete picture

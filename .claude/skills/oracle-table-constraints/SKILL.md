---
name: oracle-table-constraints
description: Use when examining Oracle table constraints (primary keys, foreign keys, unique, check constraints), understanding data integrity rules
---

# Oracle Table Constraints

## Overview

Get all constraints on Oracle tables including primary keys, foreign keys, unique constraints, and check constraints using SQLcl metadata queries.

**Core principle:** Query USER_CONSTRAINTS to understand table relationships and data integrity rules, never assume constraint structure.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks "what constraints are on EMPLOYEES?"
- User needs to understand primary key structure
- User wants to find foreign key relationships
- User needs to know unique constraints
- You're tempted to guess which column is the primary key

**When NOT to use:**
- Getting full table schema → use oracle-table-schema
- Understanding all relationships → use oracle-table-relationships
- Finding indexes on tables → use oracle-table-indexes

## SQLcl Query Patterns

### All Constraints on Table

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN constraint_name FORMAT A30
COLUMN constraint_type FORMAT A15
COLUMN table_name FORMAT A25

SELECT constraint_name, constraint_type, table_name
FROM user_constraints
WHERE table_name = 'EMPLOYEES'
ORDER BY constraint_type, constraint_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Primary Keys Only

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN constraint_name FORMAT A30
COLUMN table_name FORMAT A25
COLUMN column_name FORMAT A25

SELECT uc.constraint_name, uc.table_name, ucc.column_name
FROM user_constraints uc
JOIN user_cons_columns ucc ON uc.constraint_name = ucc.constraint_name
WHERE uc.table_name = 'EMPLOYEES'
  AND uc.constraint_type = 'P'
ORDER BY ucc.position;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Foreign Key Constraints

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN constraint_name FORMAT A30
COLUMN table_name FORMAT A25
COLUMN r_constraint_name FORMAT A30

SELECT constraint_name, table_name, r_constraint_name
FROM user_constraints
WHERE table_name = 'EMPLOYEES'
  AND constraint_type = 'R'
ORDER BY constraint_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Constraints with Column Details

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN constraint_name FORMAT A30
COLUMN constraint_type FORMAT A10
COLUMN column_name FORMAT A25

SELECT uc.constraint_name, uc.constraint_type, ucc.column_name
FROM user_constraints uc
JOIN user_cons_columns ucc ON uc.constraint_name = ucc.constraint_name
WHERE uc.table_name = 'EMPLOYEES'
ORDER BY uc.constraint_type, uc.constraint_name, ucc.position;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

## Constraint Types

| Type | Meaning |
|------|---------|
| P | Primary Key |
| U | Unique Constraint |
| R | Foreign Key (Referential) |
| C | Check Constraint |

## Implementation Steps

1. **User asks about constraints**
2. **Choose query type:**
   - All constraints → query user_constraints
   - Primary key only → WHERE constraint_type = 'P'
   - Foreign keys → WHERE constraint_type = 'R'
   - With columns → JOIN user_cons_columns
3. **Execute via SQLcl**
4. **Return actual results unchanged**

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| "EMPLOYEE_ID is probably the PK" | Query user_constraints first |
| Not joining with columns table | Use JOIN user_cons_columns for column names |
| Forgetting constraint types | Include constraint_type to differentiate PK/FK/U/C |
| Assuming foreign keys exist | Query metadata - verify actual relationships |

## Red Flags - STOP and Query Instead

- "The primary key is probably..."
- "It must have a foreign key to..."
- "Typical constraint would be..."

**All of these mean: Execute constraint query first.**

## Example: Show All EMPLOYEES Constraints

User: "What constraints are on the EMPLOYEES table?"

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN constraint_name FORMAT A30
COLUMN constraint_type FORMAT A15

SELECT constraint_name, constraint_type
FROM user_constraints
WHERE table_name = 'EMPLOYEES'
ORDER BY constraint_type, constraint_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

Result: Shows all constraints (PK, FK, U, C) on EMPLOYEES table

## Configuration

**SQLcl connection:** `sql hr@//localhost:1521/XEPDB1`

**Related Views:**
- user_constraints - Constraint definitions
- user_cons_columns - Constraint column mappings
- all_constraints - Constraints across all schemas

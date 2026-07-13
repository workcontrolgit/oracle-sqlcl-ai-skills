---
name: oracle-table-constraints
description: Use when examining Oracle table constraints (primary keys, foreign keys, unique, check constraints), understanding data integrity rules
---

# Oracle Table Constraints

## Overview

Get all constraints on Oracle tables using the SQLcl MCP server.

**Core principle:** Query USER_CONSTRAINTS to understand data integrity rules — never assume constraint structure.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks "what constraints are on EMPLOYEES?"
- User needs to understand primary key structure
- User wants to find foreign key relationships
- You're tempted to guess which column is the primary key

**When NOT to use:**
- Getting full table schema → use oracle-table-schema
- Understanding all relationships → use oracle-table-relationships
- Finding indexes → use oracle-table-indexes

## Execution Method — SQLcl MCP Tools

### All Constraints on a Table

```
connect: hr_local
run-sql: SELECT constraint_name, constraint_type, table_name FROM user_constraints WHERE table_name = 'EMPLOYEES' ORDER BY constraint_type, constraint_name
disconnect
```

### Primary Key Columns

```
connect: hr_local
run-sql: SELECT uc.constraint_name, uc.table_name, ucc.column_name FROM user_constraints uc JOIN user_cons_columns ucc ON uc.constraint_name = ucc.constraint_name WHERE uc.table_name = 'EMPLOYEES' AND uc.constraint_type = 'P' ORDER BY ucc.position
disconnect
```

### Foreign Key Constraints

```
connect: hr_local
run-sql: SELECT constraint_name, table_name, r_constraint_name FROM user_constraints WHERE table_name = 'EMPLOYEES' AND constraint_type = 'R' ORDER BY constraint_name
disconnect
```

### Constraints with Column Details

```
connect: hr_local
run-sql: SELECT uc.constraint_name, uc.constraint_type, ucc.column_name FROM user_constraints uc JOIN user_cons_columns ucc ON uc.constraint_name = ucc.constraint_name WHERE uc.table_name = 'EMPLOYEES' ORDER BY uc.constraint_type, uc.constraint_name, ucc.position
disconnect
```

## Constraint Types

| Type | Meaning |
|------|---------|
| P | Primary Key |
| U | Unique Constraint |
| R | Foreign Key (Referential) |
| C | Check Constraint |

## Red Flags - STOP and Query Instead

- "The primary key is probably..."
- "It must have a foreign key to..."
- "Typical constraint would be..."

**All of these mean: Use run-sql to query user_constraints first.**

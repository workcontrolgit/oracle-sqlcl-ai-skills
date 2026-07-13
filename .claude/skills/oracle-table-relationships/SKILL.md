---
name: oracle-table-relationships
description: Use when exploring Oracle table relationships, understanding foreign key dependencies, finding related tables
---

# Oracle Table Relationships

## Overview

Get all relationships between Oracle tables through foreign keys using the SQLcl MCP server.

**Core principle:** Query USER_CONSTRAINTS to find incoming and outgoing foreign keys — never assume table dependencies.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks "what tables reference DEPARTMENTS?"
- User wants to understand data dependencies
- User needs to find related tables through foreign keys
- You're tempted to guess which tables are related

**When NOT to use:**
- Getting full table constraints → use oracle-table-constraints
- Getting single table schema → use oracle-table-schema

## Execution Method — SQLcl MCP Tools

### Foreign Keys FROM a Table (outgoing)

```
connect: hr_local
run-sql: SELECT constraint_name, table_name, r_table_name FROM user_constraints WHERE table_name = 'EMPLOYEES' AND constraint_type = 'R' ORDER BY constraint_name
disconnect
```

### Foreign Keys TO a Table (incoming references)

```
connect: hr_local
run-sql: SELECT constraint_name, table_name, r_table_name FROM user_constraints WHERE r_table_name = 'DEPARTMENTS' AND constraint_type = 'R' ORDER BY constraint_name
disconnect
```

### Detailed FK Relationships (with column names)

```
connect: hr_local
run-sql: SELECT uc.constraint_name AS fk_constraint, uc.table_name AS fk_table, ucc.column_name AS fk_column, ucc2.column_name AS pk_column FROM user_constraints uc JOIN user_cons_columns ucc ON uc.constraint_name = ucc.constraint_name JOIN user_constraints uc2 ON uc.r_constraint_name = uc2.constraint_name JOIN user_cons_columns ucc2 ON uc2.constraint_name = ucc2.constraint_name WHERE uc.table_name = 'EMPLOYEES' AND uc.constraint_type = 'R' ORDER BY uc.constraint_name, ucc.position
disconnect
```

### All Related Tables (both directions)

```
connect: hr_local
run-sql: SELECT 'References' AS relationship_type, r_table_name AS related_table, constraint_name FROM user_constraints WHERE table_name = 'EMPLOYEES' AND constraint_type = 'R' UNION ALL SELECT 'Referenced By' AS relationship_type, table_name AS related_table, constraint_name FROM user_constraints WHERE r_table_name = 'EMPLOYEES' AND constraint_type = 'R' ORDER BY relationship_type, related_table
disconnect
```

## Key Concepts

- **Outgoing FK**: table_name references r_table_name (parent)
- **Incoming FK**: r_table_name is referenced BY table_name (child)
- Always check both directions for a complete picture

## Red Flags - STOP and Query Instead

- "It must reference..."
- "Probably related to..."
- "Typically points to..."

**All of these mean: Use run-sql to query foreign keys first.**

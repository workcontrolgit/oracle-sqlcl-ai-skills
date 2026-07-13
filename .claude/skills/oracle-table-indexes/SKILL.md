---
name: oracle-table-indexes
description: Use when examining Oracle table indexes, understanding query optimization, finding performance improvement opportunities
---

# Oracle Table Indexes

## Overview

Get all indexes on Oracle tables using the SQLcl MCP server.

**Core principle:** Query USER_INDEXES to discover index structure — never assume which columns are indexed.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks "what indexes exist on EMPLOYEES?"
- User wants to understand query performance
- User needs to find indexed columns
- You're tempted to guess which columns are indexed

**When NOT to use:**
- Getting full table schema → use oracle-table-schema
- Understanding constraints → use oracle-table-constraints
- Finding relationships → use oracle-table-relationships

## Execution Method — SQLcl MCP Tools

### All Indexes on a Table

```
connect: hr_local
run-sql: SELECT index_name, uniqueness, table_name FROM user_indexes WHERE table_name = 'EMPLOYEES' ORDER BY index_name
disconnect
```

### Index Columns with Position

```
connect: hr_local
run-sql: SELECT ui.index_name, uic.column_name, uic.column_position FROM user_indexes ui JOIN user_ind_columns uic ON ui.index_name = uic.index_name WHERE ui.table_name = 'EMPLOYEES' ORDER BY ui.index_name, uic.column_position
disconnect
```

### Indexes with Aggregated Column List

```
connect: hr_local
run-sql: SELECT ui.index_name, ui.uniqueness, LISTAGG(uic.column_name, ', ') WITHIN GROUP (ORDER BY uic.column_position) AS column_list FROM user_indexes ui LEFT JOIN user_ind_columns uic ON ui.index_name = uic.index_name WHERE ui.table_name = 'EMPLOYEES' GROUP BY ui.index_name, ui.uniqueness ORDER BY ui.index_name
disconnect
```

## Index Types

| Uniqueness | Meaning |
|-----------|---------|
| UNIQUE | Cannot contain duplicate values |
| NONUNIQUE | Can contain duplicate values |

## Red Flags - STOP and Query Instead

- "There's probably an index on..."
- "It must be indexed for performance..."
- "Typically indexed on..."

**All of these mean: Use run-sql to query user_indexes first.**

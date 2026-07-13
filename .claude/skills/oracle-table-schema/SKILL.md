---
name: oracle-table-schema
description: Use when querying Oracle table structure, columns, data types, or constraints - execute DESC and column metadata queries via SQLcl
---

# Oracle Table Schema

## Overview

Get detailed schema information for specific Oracle tables using the SQLcl MCP server.

**Core principle:** Query actual table metadata — never describe structure from knowledge.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks for table structure (DESC EMPLOYEES)
- User requests column information (what columns exist, what are their types)
- User needs nullable/default column details
- You're about to describe a table structure from memory

**When NOT to use:**
- Searching multiple tables by pattern → use oracle-search-tables
- Finding columns across all tables → use oracle-search-columns
- Getting relationships between tables → use oracle-table-relationships

## Execution Method — SQLcl MCP Tools

### Quick Table Structure (DESC)

```
connect: hr_local
run-sqlcl: DESC EMPLOYEES
disconnect
```

### Detailed Column Information

```
connect: hr_local
run-sql: SELECT column_name, data_type, nullable, data_length, data_precision FROM all_tab_columns WHERE table_name = 'EMPLOYEES' ORDER BY column_id
disconnect
```

### Column Comments

```
connect: hr_local
run-sql: SELECT column_name, comments FROM all_col_comments WHERE table_name = 'EMPLOYEES' ORDER BY column_id
disconnect
```

## Red Flags - STOP and Query Instead

- "I know the table structure..."
- "The EMPLOYEES table probably has..."
- "Based on typical HR schemas..."
- "It likely has EMPLOYEE_ID, FIRST_NAME..."

**All of these mean: Use run-sqlcl DESC or run-sql on all_tab_columns. Don't synthesize.**

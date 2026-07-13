---
name: oracle-search-columns
description: Use when finding columns across Oracle tables, searching for specific data elements, or discovering which tables contain certain fields
---

# Oracle Search Columns

## Overview

Search for columns across all Oracle tables using the SQLcl MCP server.

**Core principle:** Query ALL_TAB_COLUMNS to find columns — never assume which tables contain a specific field.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks "which tables have EMPLOYEE_ID?"
- User searches for columns with specific names (CUSTOMER_NAME, HIRE_DATE)
- User wants to find tables containing a particular data type
- You're tempted to guess which table has a column

**When NOT to use:**
- Getting full table schema → use oracle-table-schema
- Searching for tables by name → use oracle-search-tables
- Understanding foreign key relationships → use oracle-table-relationships

## Execution Method — SQLcl MCP Tools

### Find Tables with Specific Column

```
connect: hr_local
run-sql: SELECT table_name, column_name, data_type FROM all_tab_columns WHERE owner = 'HR' AND column_name = 'EMPLOYEE_ID' ORDER BY table_name
disconnect
```

### Search Columns by Pattern

```
connect: hr_local
run-sql: SELECT table_name, column_name, data_type FROM all_tab_columns WHERE owner = 'HR' AND column_name LIKE '%ID%' ORDER BY table_name, column_name
disconnect
```

### Find Columns by Data Type

```
connect: hr_local
run-sql: SELECT table_name, column_name, data_type FROM all_tab_columns WHERE owner = 'HR' AND data_type LIKE '%DATE%' ORDER BY table_name, column_name
disconnect
```

### Find Large VARCHAR2 Columns

```
connect: hr_local
run-sql: SELECT table_name, column_name, data_type, data_length FROM all_tab_columns WHERE owner = 'HR' AND data_type = 'VARCHAR2' AND data_length > 100 ORDER BY table_name, column_name
disconnect
```

## Common Data Types

- `VARCHAR2`, `CHAR` — Text
- `NUMBER` — Numeric
- `DATE` — Date
- `TIMESTAMP` — Timestamp
- `CLOB`, `BLOB` — Large data

## Red Flags - STOP and Query Instead

- "EMPLOYEE_ID is probably in..."
- "Companies usually store this in..."
- "That's typically called..."

**All of these mean: Use run-sql to search ALL_TAB_COLUMNS first.**

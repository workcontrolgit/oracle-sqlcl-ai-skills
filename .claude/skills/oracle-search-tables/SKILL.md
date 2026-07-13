---
name: oracle-search-tables
description: Use when finding Oracle tables by name pattern, searching for related tables, or exploring schema - execute search queries via SQLcl
---

# Oracle Search Tables

## Overview

Search for Oracle tables by name pattern using the SQLcl MCP server.

**Core principle:** Query ALL_TABLES to find tables — never guess table names.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks "are there any customer tables?"
- User searches for tables containing a keyword (employee, department, job)
- User wants to explore schema structure
- You're tempted to say "there's probably a JOBS table"

**When NOT to use:**
- Getting full details on one table → use oracle-table-schema
- Finding columns across all tables → use oracle-search-columns
- Understanding table relationships → use oracle-table-relationships

## Execution Method — SQLcl MCP Tools

### List All HR Tables

```
connect: hr_local
run-sql: SELECT table_name FROM all_tables WHERE owner = 'HR' ORDER BY table_name
disconnect
```

### Search Tables by Pattern

```
connect: hr_local
run-sql: SELECT table_name FROM all_tables WHERE owner = 'HR' AND table_name LIKE '%EMPLOYEE%' ORDER BY table_name
disconnect
```

### Find Tables with Specific Column Name

```
connect: hr_local
run-sql: SELECT DISTINCT table_name, column_name FROM all_tab_columns WHERE owner = 'HR' AND column_name LIKE '%EMPLOYEE_ID%' ORDER BY table_name, column_name
disconnect
```

### Search by Multiple Patterns

```
connect: hr_local
run-sql: SELECT table_name FROM all_tables WHERE owner = 'HR' AND (table_name LIKE '%CUSTOMER%' OR table_name LIKE '%ORDER%') ORDER BY table_name
disconnect
```

## LIKE Pattern Tips

- `LIKE 'EMPLOYEE%'` — starts with EMPLOYEE
- `LIKE '%EMPLOYEE'` — ends with EMPLOYEE
- `LIKE '%EMPLOYEE%'` — contains EMPLOYEE anywhere

## Red Flags - STOP and Query Instead

- "There's probably..."
- "Companies usually have..."
- "Standard HR schemas typically have..."

**All of these mean: Use run-sql to search ALL_TABLES first.**

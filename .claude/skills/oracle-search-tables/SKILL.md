---
name: oracle-search-tables
description: Use when finding Oracle tables by name pattern, searching for related tables, or exploring schema - execute search queries via SQLcl
---

# Oracle Search Tables

## Overview

Search for Oracle tables by name pattern, matching keywords, or exploring available tables using SQLcl metadata queries.

**Core principle:** Query ALL_TABLES to find tables, never guess table names based on assumed naming conventions.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks "are there any customer tables?"
- User searches for tables containing specific word (employee, department, job)
- User wants to explore schema structure
- User needs to find related tables
- You're tempted to say "there's probably a JOBS table"

**When NOT to use:**
- Getting full details on one table → use oracle-table-schema
- Finding columns across all tables → use oracle-search-columns
- Understanding table relationships → use oracle-table-relationships

## SQLcl Query Patterns

### List All HR Tables

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN table_name FORMAT A35

SELECT table_name
FROM all_tables
WHERE owner = 'HR'
ORDER BY table_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Search Tables by Pattern

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN table_name FORMAT A35

SELECT table_name
FROM all_tables
WHERE owner = 'HR' 
  AND table_name LIKE '%EMPLOYEE%'
ORDER BY table_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Find Tables with Column Name

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN table_name FORMAT A30
COLUMN column_name FORMAT A30

SELECT DISTINCT table_name, column_name
FROM all_tab_columns
WHERE owner = 'HR' 
  AND column_name LIKE '%EMPLOYEE_ID%'
ORDER BY table_name, column_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Search by Multiple Patterns

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN table_name FORMAT A35
COLUMN table_type FORMAT A15

SELECT table_name, table_type
FROM all_tables
WHERE owner = 'HR' 
  AND (table_name LIKE '%CUSTOMER%' OR table_name LIKE '%ORDER%')
ORDER BY table_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

## Implementation Steps

1. **User searches for tables**
2. **Choose query type:**
   - List all tables → query all_tables where owner = 'HR'
   - Search by name pattern → use LIKE clause
   - Find by column name → query all_tab_columns
   - Multiple patterns → use OR in WHERE clause
3. **Use % wildcards** for pattern matching
4. **Execute via SQLcl**
5. **Return actual results unchanged**

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| "There's probably a CUSTOMERS table" | Execute LIKE search first - may not exist |
| Assuming table naming convention | Query metadata - let oracle tell you |
| Only checking table names | Also search column names (LIKE in all_tab_columns) |
| Forgetting owner filter | Always add WHERE owner = 'HR' |
| Case sensitivity issues | Oracle stores uppercase - query with uppercase |

## Red Flags - STOP and Query Instead

- "There's probably..."
- "Companies usually have..."
- "Standard HR schemas typically have..."
- "It's likely called..."

**All of these mean: Execute search query first.**

## Example: Find All EMPLOYEE-Related Tables

User: "What tables have 'EMPLOYEE' in the name?"

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN table_name FORMAT A35

SELECT table_name
FROM all_tables
WHERE owner = 'HR' 
  AND table_name LIKE '%EMPLOYEE%'
ORDER BY table_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

Result: EMPLOYEES, EMPLOYEE_HISTORY (or whatever actually exists)

## Configuration

**SQLcl connection:** `sql hr@//localhost:1521/XEPDB1`

**LIKE Pattern Tips:**
- `LIKE 'EMPLOYEE%'` - starts with EMPLOYEE
- `LIKE '%EMPLOYEE'` - ends with EMPLOYEE  
- `LIKE '%EMPLOYEE%'` - contains EMPLOYEE anywhere
- `LIKE '_____'` - exactly 5 characters (use underscore)

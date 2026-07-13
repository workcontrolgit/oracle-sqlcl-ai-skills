---
name: oracle-search-columns
description: Use when finding columns across Oracle tables, searching for specific data elements, or discovering which tables contain certain fields
---

# Oracle Search Columns

## Overview

Search for columns across all Oracle tables by name pattern, finding which tables contain specific data elements using SQLcl metadata queries.

**Core principle:** Query ALL_TAB_COLUMNS to find columns, never assume which tables contain a specific field.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks "which tables have EMPLOYEE_ID?"
- User searches for columns with specific names (CUSTOMER_NAME, HIRE_DATE)
- User wants to find tables containing a particular data type
- User needs to discover schema structure
- You're tempted to guess which table has a column

**When NOT to use:**
- Getting full table schema → use oracle-table-schema
- Searching for tables by name → use oracle-search-tables
- Understanding foreign key relationships → use oracle-table-relationships

## SQLcl Query Patterns

### Find Tables with Specific Column

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN table_name FORMAT A25
COLUMN column_name FORMAT A25
COLUMN data_type FORMAT A15

SELECT table_name, column_name, data_type
FROM all_tab_columns
WHERE owner = 'HR' 
  AND column_name = 'EMPLOYEE_ID'
ORDER BY table_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Search Columns by Pattern

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN table_name FORMAT A25
COLUMN column_name FORMAT A25
COLUMN data_type FORMAT A15

SELECT table_name, column_name, data_type
FROM all_tab_columns
WHERE owner = 'HR' 
  AND column_name LIKE '%ID%'
ORDER BY table_name, column_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Find Columns by Data Type

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN table_name FORMAT A25
COLUMN column_name FORMAT A25
COLUMN data_type FORMAT A15

SELECT table_name, column_name, data_type
FROM all_tab_columns
WHERE owner = 'HR' 
  AND data_type LIKE '%DATE%'
ORDER BY table_name, column_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Find Columns with Specific Size

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN table_name FORMAT A25
COLUMN column_name FORMAT A25
COLUMN data_type FORMAT A15
COLUMN data_length FORMAT 9999

SELECT table_name, column_name, data_type, data_length
FROM all_tab_columns
WHERE owner = 'HR' 
  AND data_type = 'VARCHAR2'
  AND data_length > 100
ORDER BY table_name, column_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

## Implementation Steps

1. **User searches for columns**
2. **Choose query type:**
   - Exact column name → WHERE column_name = 'COLUMN_NAME'
   - Pattern search → WHERE column_name LIKE '%PATTERN%'
   - By data type → WHERE data_type = 'VARCHAR2'
   - By size → WHERE data_length > value
3. **Always filter by owner = 'HR'**
4. **Use LIKE % for pattern matching**
5. **Execute via SQLcl**
6. **Return actual results unchanged**

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| "EMPLOYEE_ID is probably in EMPLOYEES" | Execute search query first - may be in multiple tables |
| Forgetting owner filter | Always add WHERE owner = 'HR' |
| Case sensitivity | Oracle stores uppercase - query with uppercase |
| Not specifying exact column name | Use exact name or LIKE pattern, not partial guess |
| Assuming data types | Query metadata - let oracle show you |

## Red Flags - STOP and Query Instead

- "EMPLOYEE_ID is probably in..."
- "Companies usually store this in..."
- "That's typically called..."
- "It must be..."

**All of these mean: Execute search query first.**

## Example: Find All Tables with SALARY Column

User: "Which tables have salary information?"

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN table_name FORMAT A25
COLUMN column_name FORMAT A25

SELECT table_name, column_name, data_type
FROM all_tab_columns
WHERE owner = 'HR' 
  AND column_name LIKE '%SALARY%'
ORDER BY table_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

Result: Shows all tables containing columns with "SALARY" in the name

## Configuration

**SQLcl connection:** `sql hr@//localhost:1521/XEPDB1`

**Common Data Types to Query:**
- VARCHAR2, CHAR - Text data
- NUMBER, INT - Numeric data
- DATE - Date columns
- CLOB, BLOB - Large data
- TIMESTAMP - Timestamp data

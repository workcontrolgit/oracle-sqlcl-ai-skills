---
name: oracle-sql-query
description: Use when executing arbitrary SQL queries against Oracle database, fetching data, or running custom analysis via SQLcl
---

# Oracle SQL Query

## Overview

Execute arbitrary SQL queries against the Oracle database using SQLcl to fetch data, perform analysis, or test custom SQL statements.

**Core principle:** Format queries properly with SET commands for consistent output, always use SELECT for read-only queries.

## When to Use

**SYMPTOMS that trigger this skill:**
- User provides a specific SQL query to run
- User wants to fetch data from tables
- User needs to perform custom analysis
- User wants to test SQL before deployment
- User needs data validation or reports

**When NOT to use:**
- Exploring table schema → use oracle-table-schema
- Searching for tables → use oracle-search-tables
- Finding relationships → use oracle-table-relationships

## SQLcl Query Pattern

### Basic Query Execution

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200

[YOUR SQL QUERY HERE]

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Query with Column Formatting

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN employee_id FORMAT 9999
COLUMN first_name FORMAT A15
COLUMN salary FORMAT $99,999.99

SELECT employee_id, first_name, salary
FROM employees
ORDER BY employee_id;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Query with Aggregation

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN department_id FORMAT 999
COLUMN avg_salary FORMAT $99,999.99
COLUMN max_salary FORMAT $99,999.99

SELECT department_id, 
       COUNT(*) AS employee_count,
       AVG(salary) AS avg_salary,
       MAX(salary) AS max_salary
FROM employees
GROUP BY department_id
ORDER BY department_id;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Query with Joins

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN employee_name FORMAT A25
COLUMN department_name FORMAT A25
COLUMN job_id FORMAT A15

SELECT e.first_name || ' ' || e.last_name AS employee_name,
       d.department_name,
       e.job_id,
       e.salary
FROM employees e
JOIN departments d ON e.department_id = d.department_id
ORDER BY d.department_name, e.last_name;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

## Implementation Steps

1. **User provides SQL query**
2. **Wrap query with SET commands:**
   - SET HEADING ON
   - SET FEEDBACK ON
   - SET PAGESIZE 200
   - SET LINESIZE 200
3. **Add COLUMN formatting if needed** for readability
4. **Execute via SQLcl**
5. **Return actual results unchanged**

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Query returns no results | Check WHERE clause and table names exist |
| Columns too narrow to display | Add COLUMN [name] FORMAT [A##\|999] |
| No headers in output | SET HEADING ON must be included |
| Numbers truncated | Use NUMBER format like 9999.99 |
| Missing data | Verify table names, column names, and JOIN conditions |

## Red Flags - Query Issues

- Syntax error in query → Check SQL syntax
- No results returned → Verify table/column names and WHERE clause
- Unexpected results → Review JOIN conditions and ORDER BY
- Performance issue → Consider adding WHERE clause to limit results

## Format Types

| Format | Usage | Example |
|--------|-------|---------|
| A## | Text (max width) | COLUMN name FORMAT A20 |
| 999 | Integer | COLUMN id FORMAT 999 |
| 9999.99 | Decimal | COLUMN salary FORMAT 9999.99 |
| $99,999.99 | Currency | COLUMN price FORMAT $99,999.99 |
| 0.00EEEE | Scientific | COLUMN value FORMAT 0.00EEEE |

## Example: Get Employee Count by Department

User: "How many employees work in each department?"

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN department_id FORMAT 999
COLUMN employee_count FORMAT 999

SELECT department_id, COUNT(*) AS employee_count
FROM employees
GROUP BY department_id
ORDER BY department_id;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

## Configuration

**SQLcl connection:** `sql hr@//localhost:1521/XEPDB1`

**Important:**
- Read-only mode enabled by default
- Only SELECT statements are permitted
- Write operations (INSERT, UPDATE, DELETE) are blocked for security
- All queries run as HR user

## Tips

- Use `LISTAGG()` to aggregate multiple rows into one
- Use `WITH` clause for complex queries (subquery factoring)
- Add `EXPLAIN PLAN FOR` before query to see execution plan
- Use `COUNT(*)` for row counts, `COUNT(column)` for non-null counts

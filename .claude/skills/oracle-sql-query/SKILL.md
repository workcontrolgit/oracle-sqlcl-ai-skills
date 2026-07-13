---
name: oracle-sql-query
description: Use when executing arbitrary SQL queries against Oracle database, fetching data, or running custom analysis via SQLcl
---

# Oracle SQL Query

## Overview

Execute arbitrary SQL queries against the Oracle database using the SQLcl MCP server.

**Core principle:** Always execute real SQL via MCP tools — never guess or synthesize results.

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

## Execution Method — SQLcl MCP Tools

Use MCP tools in this order:

1. **`connect`** — connect to the saved `hr_local` connection
2. **`run-sql`** — execute the SQL query
3. **`disconnect`** — close the connection

### Basic Query

```
connect: hr_local
run-sql: SELECT employee_id, first_name, salary FROM employees ORDER BY employee_id
disconnect
```

### Aggregation Query

```
connect: hr_local
run-sql: SELECT department_id, COUNT(*) AS employee_count, AVG(salary) AS avg_salary, MAX(salary) AS max_salary FROM employees GROUP BY department_id ORDER BY department_id
disconnect
```

### Join Query

```
connect: hr_local
run-sql: SELECT e.first_name || ' ' || e.last_name AS employee_name, d.department_name, e.job_id, e.salary FROM employees e JOIN departments d ON e.department_id = d.department_id ORDER BY d.department_name, e.last_name
disconnect
```

### SQLcl-Specific Commands (SET, DDL, etc.)

Use `run-sqlcl` instead of `run-sql` for SQLcl commands:

```
connect: hr_local
run-sqlcl: SET SQLFORMAT json
run-sql: SELECT * FROM employees
disconnect
```

## Implementation Steps

1. **User provides SQL query**
2. **Connect** via `connect` MCP tool with `hr_local`
3. **Execute** via `run-sql` MCP tool
4. **Disconnect** via `disconnect` MCP tool
5. **Return actual results unchanged**

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Query returns no results | Check WHERE clause and table names exist |
| No headers in output | Results come back structured from MCP |
| Missing data | Verify table names, column names, and JOIN conditions |

## Tips

- Use `LISTAGG()` to aggregate multiple rows into one
- Use `WITH` clause for complex queries (subquery factoring)
- Use `COUNT(*)` for row counts, `COUNT(column)` for non-null counts
- Read-only — SELECT statements only; DDL/DML requires explicit approval

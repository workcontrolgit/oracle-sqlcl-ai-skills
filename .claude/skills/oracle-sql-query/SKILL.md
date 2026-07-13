---
name: oracle-sql-query
description: Use when executing any SQL query against Oracle database - HR data, schema exploration, custom analysis, or arbitrary SQL
---

# Oracle SQL Query

## Overview

Execute SQL queries against the Oracle database using the SQLcl MCP server. Covers HR data queries, schema exploration, and any custom SQL.

**Core principle:** Always execute real SQL via MCP tools — never guess or synthesize results.

## When to Use

- User asks about HR tables, employees, departments, jobs, locations, regions
- User provides a specific SQL query to run
- User wants to fetch, filter, or aggregate data
- User needs schema exploration (tables, columns, constraints, indexes, relationships)
- User needs custom analysis or reports
- You're tempted to describe data or schema from knowledge instead of querying

**When NOT to use:**
- Searching tables by name pattern → use oracle-search-tables
- Finding columns across all tables → use oracle-search-columns
- Viewing constraints → use oracle-table-constraints
- Viewing indexes → use oracle-table-indexes
- Viewing relationships → use oracle-table-relationships
- Describing a table's structure → use oracle-table-schema

## Execution Method — SQLcl MCP Tools

Use MCP tools in this order:

1. **`connect`** — connect to the saved `hr_local` connection
2. **`run-sql`** — execute the SQL query
3. **`disconnect`** — close the connection

For SQLcl-specific commands (SET, DESC, DDL):
- Use **`run-sqlcl`** instead of `run-sql`

## Common Query Examples

### HR Data

```
connect: hr_local
run-sql: SELECT * FROM departments ORDER BY department_id
disconnect
```

```
connect: hr_local
run-sql: SELECT employee_id, first_name, last_name, job_id, salary FROM employees WHERE department_id = 10 ORDER BY last_name
disconnect
```

```
connect: hr_local
run-sql: SELECT e.first_name || ' ' || e.last_name AS employee_name, d.department_name, e.salary FROM employees e JOIN departments d ON e.department_id = d.department_id ORDER BY d.department_name, e.last_name
disconnect
```

### Schema Exploration

```
connect: hr_local
run-sql: SELECT table_name FROM all_tables WHERE owner = 'HR' ORDER BY table_name
disconnect
```

```
connect: hr_local
run-sqlcl: DESC EMPLOYEES
disconnect
```

### Aggregation

```
connect: hr_local
run-sql: SELECT department_id, COUNT(*) AS employee_count, AVG(salary) AS avg_salary FROM employees GROUP BY department_id ORDER BY department_id
disconnect
```

## Critical Rules

**DO:**
- Use `connect` before any query
- Use `run-sql` for SQL, `run-sqlcl` for SQLcl commands (DESC, SET)
- Use `disconnect` after finishing
- Return actual results unchanged

**DON'T:**
- Synthesize or guess data/schema from knowledge
- Skip actual query execution

## HR Schema Quick Reference

**Tables:** REGIONS, COUNTRIES, LOCATIONS, DEPARTMENTS, JOBS, EMPLOYEES, JOB_HISTORY

**Key relationships:**
- EMPLOYEES.DEPARTMENT_ID → DEPARTMENTS.DEPARTMENT_ID
- EMPLOYEES.JOB_ID → JOBS.JOB_ID
- EMPLOYEES.MANAGER_ID → EMPLOYEES.EMPLOYEE_ID (self-ref)
- DEPARTMENTS.LOCATION_ID → LOCATIONS.LOCATION_ID
- LOCATIONS.COUNTRY_ID → COUNTRIES.COUNTRY_ID
- COUNTRIES.REGION_ID → REGIONS.REGION_ID

## Connection

```
Saved connection: hr_local
Host: localhost | Port: 1521 | Service: XEPDB1 | User: hr
```

---
name: oracle-hr-query
description: Use when querying Oracle HR database schema or data, before synthesizing or guessing results - always run actual SQL
---

# Oracle HR Query

## Overview
Execute actual SQL queries against the Oracle HR database via the SQLcl MCP server. Never synthesize or hallucinate schema/data — run queries and return real results.

**Core principle:** Real query execution > hallucinated schema synthesis

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks about HR tables, columns, relationships
- User requests specific employee, department, or job data
- User needs schema exploration (what tables exist, structure, constraints)
- You're tempted to "just describe" the HR schema from knowledge
- Any request involving `EMPLOYEES`, `DEPARTMENTS`, `JOBS`, `LOCATIONS`, `REGIONS`, `COUNTRIES`, `JOB_HISTORY`

**When NOT to use:**
- Planning queries (before execution)
- Discussing SQL syntax (not about HR data specifically)
- Describing generic database concepts

## Execution Method — SQLcl MCP Tools

Always use the MCP tools in this order:

1. **`connect`** — connect to the saved `hr_local` connection
2. **`run-sql`** — execute the SQL query
3. **`disconnect`** — close the connection

### Example: Query departments

```
connect: hr_local
run-sql: SELECT * FROM departments ORDER BY department_id
disconnect
```

### Example: Query employees by department

```
connect: hr_local
run-sql: SELECT employee_id, first_name, last_name, job_id, salary FROM employees WHERE department_id = 10 ORDER BY last_name
disconnect
```

### Example: Describe table structure

```
connect: hr_local
run-sql: SELECT column_name, data_type, nullable, data_length FROM all_tab_columns WHERE table_name = 'EMPLOYEES' ORDER BY column_id
disconnect
```

## Common Queries

### List All Tables
```sql
SELECT table_name FROM all_tables WHERE owner = 'HR' ORDER BY table_name
```

### Show Table Structure
```sql
SELECT column_name, data_type, nullable FROM all_tab_columns WHERE table_name = 'EMPLOYEES' ORDER BY column_id
```

### Query Employees
```sql
SELECT employee_id, first_name, last_name, job_id, salary FROM employees WHERE department_id = 10 ORDER BY last_name
```

### Show Relationships
```sql
SELECT constraint_name, constraint_type, table_name FROM user_constraints WHERE table_name IN ('EMPLOYEES', 'DEPARTMENTS', 'JOBS') ORDER BY table_name, constraint_name
```

## Critical Rules

**DO:**
- Use `connect` MCP tool before running any query
- Use `run-sql` MCP tool for SQL execution
- Use `disconnect` after finishing
- Return actual query results unchanged

**DON'T:**
- Synthesize schema from knowledge
- Guess table names or columns
- Hallucinate data or relationships
- Skip actual query execution

## Red Flags - Stop and Query Instead

- "I know the HR schema..."
- "The EMPLOYEES table likely has..."
- "There's probably a foreign key to..."
- "Based on typical HR schemas..."

**All of these mean: Use run-sql MCP tool. Don't synthesize.**

## Connection Details

```
Saved connection name: hr_local
Host:     localhost
Port:     1521
Service:  XEPDB1
User:     hr
```

## HR Schema Quick Reference

**Core tables:**
- `REGIONS` - Geographic regions
- `COUNTRIES` - Countries by region
- `LOCATIONS` - Office locations by country
- `DEPARTMENTS` - Departments by location
- `JOBS` - Job titles and salary ranges
- `EMPLOYEES` - Employee data (hire_date, salary, manager_id)
- `JOB_HISTORY` - Historical job assignments

**Key relationships:**
- EMPLOYEES.DEPARTMENT_ID → DEPARTMENTS.DEPARTMENT_ID
- EMPLOYEES.JOB_ID → JOBS.JOB_ID
- EMPLOYEES.MANAGER_ID → EMPLOYEES.EMPLOYEE_ID (self-reference)
- DEPARTMENTS.LOCATION_ID → LOCATIONS.LOCATION_ID
- LOCATIONS.COUNTRY_ID → COUNTRIES.COUNTRY_ID
- COUNTRIES.REGION_ID → REGIONS.REGION_ID

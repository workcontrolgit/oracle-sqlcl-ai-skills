---
name: oracle-hr-query
description: Use when querying Oracle HR database schema or data, before synthesizing or guessing results - always run actual SQL
---

# Oracle HR Query

## Overview
Execute actual SQL queries against the Oracle HR database via SQLcl. Never synthesize or hallucinate schema/data—run queries and return real results.

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

## Connection Details

```
Host:     localhost
Port:     1521
Service:  XEPDB1
User:     hr
Password: HrUser_2026

Connection string: sql hr@//localhost:1521/XEPDB1
```

## SQL Query Pattern

**Primary method - SQLcl (if installed):**

```bash
cat << 'EOF' | sql hr@//localhost:1521/XEPDB1
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200

[YOUR SQL HERE]

EXIT;
EOF
```

**If SQLcl unavailable - Use Python with cx_Oracle:**

```python
import cx_Oracle

conn = cx_Oracle.connect('hr/HrUser_2026@localhost:1521/XEPDB1')
cursor = conn.cursor()
cursor.execute('[YOUR SQL HERE]')

for row in cursor.fetchall():
    print(row)

cursor.close()
conn.close()
```

**Configuration flags explained (SQLcl):**
- `SET HEADING ON` - Display column headers
- `SET FEEDBACK ON` - Show row counts
- `SET PAGESIZE 200` - Results per page
- `SET LINESIZE 200` - Max line width

## Common Queries

### List All Tables
```sql
COLUMN table_name FORMAT A35
SELECT table_name
FROM all_tables
WHERE owner = 'HR'
ORDER BY table_name;
```

### Show Table Structure
```sql
DESC EMPLOYEES;
DESC DEPARTMENTS;
DESC JOBS;
```

### Query Employees
```sql
SELECT employee_id, first_name, last_name, job_id, salary
FROM employees
WHERE department_id = 10
ORDER BY last_name;
```

### Show Relationships
```sql
SELECT constraint_name, constraint_type, table_name
FROM user_constraints
WHERE table_name IN ('EMPLOYEES', 'DEPARTMENTS', 'JOBS')
ORDER BY table_name, constraint_name;
```

### Check HR User
```sql
SELECT username, account_status
FROM dba_users
WHERE username = 'HR';
```
(Note: Requires `SYSTEM` user connection)

## Critical Rules

**DO:**
- Run queries via SQLcl for real results
- Format queries with SET HEADING, SET FEEDBACK, SET PAGESIZE
- Return actual query output unchanged
- Show schema facts from query results

**DON'T:**
- Synthesize schema from knowledge
- Guess table names or columns
- Hallucinate data or relationships
- Skip the actual query execution
- Assume schema structure without verification

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| "The HR schema has X tables..." | Run actual query listing tables first |
| "EMPLOYEES table probably has..." | Query DESC EMPLOYEES; don't assume |
| "There's likely a JOBS table" | Verify with SELECT from all_tables |
| Returning formatted schema without executing | Execute query, return actual results |
| Copying schema from memory | Query is source of truth, not knowledge |

## Red Flags - Stop and Query Instead

- "I know the HR schema..."
- "The EMPLOYEES table likely has..."
- "There's probably a foreign key to..."
- "Based on typical HR schemas..."
- "I can describe the structure..."

**All of these mean: Execute actual query. Don't synthesize.**

## Implementation

1. **User asks about HR schema/data**
2. **Identify the question** (schema structure? specific data? relationships?)
3. **Write appropriate SQL** (DESC for structure, SELECT for data, user_constraints for relationships)
4. **Choose execution method** (SQLcl preferred, Python if SQLcl unavailable)
5. **Execute query**
6. **Return actual results unchanged**

Example workflow - SQLcl:
```bash
# User: "Show me the EMPLOYEES table structure"
cat << 'EOF' | sql hr@//localhost:1521/XEPDB1
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200

DESC EMPLOYEES;

EXIT;
EOF
```

Example workflow - Python:
```python
import cx_Oracle

conn = cx_Oracle.connect('hr/HrUser_2026@localhost:1521/XEPDB1')
cursor = conn.cursor()
cursor.execute('DESC EMPLOYEES')
for row in cursor.fetchall():
    print(row)
cursor.close()
conn.close()
```

## Environment Troubleshooting

**If SQLcl not found (`sql` command fails):**
1. Check if cx_Oracle is installed: `python3 -c "import cx_Oracle"`
2. If yes → Use Python method above
3. If no → User needs to install Oracle client tools

**If cx_Oracle import fails:**
- Install: `pip install cx_Oracle oracledb`
- Or: Use the Docker oracle-hr container's SQLcl directly
- Or: User installs Oracle SQLcl/SQL*Plus locally

**Network connectivity issues:**
- Verify container running: `docker ps | grep oracle`
- Test connection: `nc -zv localhost 1521`
- Credentials: hr/HrUser_2026 (XEPDB1 service)

## HR Schema Quick Reference

**Core tables:**
- `REGIONS` - Geographic regions
- `COUNTRIES` - Countries by region
- `LOCATIONS` - Office locations by country
- `DEPARTMENTS` - Departments by location
- `JOBS` - Job titles and salary ranges
- `EMPLOYEES` - Employee data (hire_date, salary, manager_id)
- `JOB_HISTORY` - Historical job assignments (employee movement tracking)

**Key relationships:**
- EMPLOYEES.DEPARTMENT_ID → DEPARTMENTS.DEPARTMENT_ID
- EMPLOYEES.JOB_ID → JOBS.JOB_ID
- EMPLOYEES.MANAGER_ID → EMPLOYEES.EMPLOYEE_ID (self-reference)
- DEPARTMENTS.LOCATION_ID → LOCATIONS.LOCATION_ID
- LOCATIONS.COUNTRY_ID → COUNTRIES.COUNTRY_ID
- COUNTRIES.REGION_ID → REGIONS.REGION_ID

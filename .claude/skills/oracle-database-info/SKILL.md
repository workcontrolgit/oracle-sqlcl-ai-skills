---
name: oracle-database-info
description: Use when checking Oracle database version, schema information, or gathering database metadata
---

# Oracle Database Info

## Overview

Get Oracle database version, schema information, and database configuration using SQLcl metadata queries.

**Core principle:** Query database views to get authoritative version and configuration information, never assume database version.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks "what Oracle version are we running?"
- User wants database metadata (name, version, instance info)
- User needs schema owner information
- You're tempted to guess the database version

## SQLcl Query Patterns

### Database Version and System Info

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200

SELECT * FROM v\$version;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Connected User Info

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200

SELECT user FROM dual;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### Database Name and Instance

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200

SELECT name FROM v\$database;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### HR Schema Objects Summary

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN object_type FORMAT A20
COLUMN object_count FORMAT 999

SELECT object_type, COUNT(*) AS object_count
FROM user_objects
GROUP BY object_type
ORDER BY object_count DESC;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

### All Schemas Available

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN username FORMAT A30

SELECT username FROM dba_users WHERE account_status = 'OPEN' ORDER BY username;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

## Implementation Steps

1. **User asks about database info**
2. **Choose query type:**
   - Version info → query v$version
   - Current user → SELECT user FROM dual
   - Database name → query v$database
   - Schema objects → GROUP BY object_type
   - Available users → query dba_users
3. **Execute via SQLcl**
4. **Return actual results unchanged**

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| "It's probably Oracle 21c" | Query v\$version first |
| Assuming database name | Query v\$database for actual name |
| Not checking user permissions | Query dba_users to see available schemas |

## Red Flags - STOP and Query Instead

- "Probably running..."
- "Must be version..."
- "It's likely..."

**All of these mean: Query v\$version first.**

## Example: Check Oracle Database Version

User: "What Oracle version is this?"

```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200

SELECT * FROM v\$version;

EXIT;
"@ | sql hr@//localhost:1521/XEPDB1
```

Result: Shows Oracle database version and component details

## Configuration

**SQLcl connection:** `sql hr@//localhost:1521/XEPDB1`

**Key Views:**
- v$version - Database version and components
- v$database - Database name and properties
- dba_users - All user accounts
- user_objects - Objects in current schema
- dba_objects - Objects across all schemas (if accessible)

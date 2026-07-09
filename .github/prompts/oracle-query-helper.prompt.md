---
name: Oracle Query Helper
description: Reusable helper for connecting to the local Oracle XE container and running SQL queries against the HR schema.
---

Use this workspace’s Oracle XE container to run SQL queries against the HR schema using SQLcl.

Connection details:
- Container: `oracle-hr`
- Host: `localhost`
- Port: `1521`
- Service: `XEPDB1`
- System user: `system`
- System password: `OracleSys_2026`
- HR user: `hr`
- HR password: `HrUser_2026`

Preferred workflow:
1. Confirm the container is running with `docker ps` if needed.
2. Use SQLcl when you want a reusable login with `savepw`.
3. Run the query with `SET HEADING ON`, `SET FEEDBACK ON`, and a reasonable `PAGESIZE` and `LINESIZE`.
4. Prefer `HR` queries for application objects. Use `SYSTEM` only when checking users, privileges, or container health.
5. If a query fails, surface the Oracle error directly and adjust the connection or SQL before retrying.

SQLcl reusable login example:
```powershell
sql hr@//localhost:1521/XEPDB1
savepw
```

After saving the password, reconnect with the same SQLcl connection without retyping the password.

Common examples:

List HR tables:
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

Check the HR user:
```powershell
@"
SET HEADING ON
SET FEEDBACK ON
SELECT username, account_status
FROM dba_users
WHERE username = 'HR';
EXIT;
"@ | sql system@//localhost:1521/XEPDB1
```

If the user asks for a new query, convert it into a compact SQLcl script using this same pattern.
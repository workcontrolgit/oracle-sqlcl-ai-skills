---
name: oracle-database-info
description: Use when checking Oracle database version, schema information, gathering database metadata, or listing available saved connections
---

# Oracle Database Info

## Overview

Get Oracle database version, schema information, and database configuration using the SQLcl MCP server.

**Core principle:** Query database views for authoritative version and configuration information — never assume or guess.

## When to Use

**SYMPTOMS that trigger this skill:**
- User asks "what Oracle version are we running?"
- User wants database metadata (name, version, instance info)
- User needs schema owner information
- User asks "what connections are available?" or "what databases can I connect to?"
- You're tempted to guess the database version

## Execution Method — SQLcl MCP Tools

Use MCP tools in this order:

1. **`connect`** — connect to the saved `hr_local` connection
2. **`run-sql`** — execute the metadata query
3. **`disconnect`** — close the connection

### Database Version

```
connect: hr_local
run-sql: SELECT * FROM v$version
disconnect
```

### Connected User

```
connect: hr_local
run-sql: SELECT user FROM dual
disconnect
```

### HR Schema Objects Summary

```
connect: hr_local
run-sql: SELECT object_type, COUNT(*) AS object_count FROM user_objects GROUP BY object_type ORDER BY object_count DESC
disconnect
```

### All Open Schemas

```
connect: hr_local
run-sql: SELECT username FROM dba_users WHERE account_status = 'OPEN' ORDER BY username
disconnect
```

### List Available Saved Connections

Use `list-connections` — no connect/disconnect needed:

```
list-connections
```

This calls the MCP tool directly and returns all saved SQLcl connections the user has configured.

## Key Views

| View | Purpose |
|------|---------|
| `v$version` | Database version and components |
| `v$database` | Database name and properties |
| `dba_users` | All user accounts |
| `user_objects` | Objects in current schema |
| `dba_objects` | Objects across all schemas |

## Red Flags - STOP and Query Instead

- "Probably running..."
- "Must be version..."
- "It's likely..."

**All of these mean: Use run-sql to query v$version first.**

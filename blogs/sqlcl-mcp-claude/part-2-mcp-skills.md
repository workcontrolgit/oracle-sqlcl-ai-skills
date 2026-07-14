# Talk to Oracle with Claude AI — Part 2: MCP Server + Claude Skills

In Part 1 you installed the Oracle SQL Developer extension and spun up a
Docker Oracle HR database. Now you'll wire Claude Code to that database using
the SQLcl MCP server — and install the skills that let Claude query Oracle
with plain English.

**Series:**
- Part 1: Setup — VS Code extension, Docker HR schema
- Part 2: MCP Server Configuration + Claude Skills ← you are here
- Part 3: Prompt Demos — Querying Oracle in Plain English

---

## What is MCP?

The **Model Context Protocol** (MCP) is an open standard that lets AI models
call external tools in a structured, type-safe way. Instead of writing bash
scripts that pipe SQL through Claude's context, MCP gives the AI a proper
tool interface — with named tools, typed parameters, and structured responses.

SQLcl 24+ ships with a built-in MCP server. When Claude Code connects to it,
Claude gets direct access to tools like `sql_run`, `connect`, and
`schema_information` — no scripting glue required.

---

## Configure the MCP Server

The demo repo ships with `.mcp.json` at the project root. This is Claude Code's
**project-scoped MCP config** — it's checked into git and shared with the team.

```json
{
  "mcpServers": {
    "sqlcl": {
      "type": "stdio",
      "command": "C:\\Users\\<you>\\.vscode\\extensions\\oracle.sql-developer-<version>-win32-x64\\dbtools\\sqlcl\\bin\\sql.exe",
      "args": ["-mcp"]
    }
  }
}
```

**Update the `command` path** to match your local SQLcl location (the path you
found in Part 1).

> ⚠️ The config file is `.mcp.json` at the project root — not `.claude/mcp.json`.
> Claude Code only reads the project-scoped MCP config from `.mcp.json`.

### How it works

When Claude Code starts, it reads `.mcp.json` and launches the `sqlcl -mcp`
process as a subprocess. Claude communicates with SQLcl over stdin/stdout using
JSON-RPC — the same protocol used by all MCP servers.

SQLcl runs in MCP mode and waits for tool calls. When you ask Claude a database
question, Claude picks the right MCP tool, calls it with the appropriate
parameters, and uses the response to answer you.

### Load the MCP Server

After updating the path in `.mcp.json`:

1. Open the project folder in VS Code
2. Press `Ctrl+Shift+P` → **Developer: Reload Window**
3. Start a new Claude Code chat session
4. Type `/mcp` to verify

You should see:

```
sqlcl  ✓ connected
```

> 💡 If the server doesn't appear, check that your `command` path points to the
> correct `sql.exe` inside the Oracle SQL Developer extension folder. The path
> changes with each extension version update.

---

## Available SQLcl MCP Tools

Once connected, Claude has access to these tools — it selects them automatically
based on your question:

| Tool | What it does |
|------|--------------|
| `connections_list` | List all saved Oracle connections |
| `connect` | Connect to a named saved connection |
| `schema_information` | Get schema overview (tables, object types) |
| `sql_run` | Execute SQL queries |
| `sqlcl_run` | Execute SQLcl commands (SET, DDL, Liquibase) |
| `disconnect` | Close the current connection |
| `request_status` | Check current connection status |

You don't call these tools directly — Claude selects the right tool and
parameters automatically when you ask a question. The tool list is what Claude
sees; what you see is just the answer.

---

## Claude Skills — Plain English to Oracle

The repo's `.claude/skills/` folder contains **Claude AI skills** — pre-built
prompt templates that give Claude focused instructions for specific database
tasks. You invoke them with a `/skill-name` command in the chat.

| Skill | Invoke with | What it does |
|-------|-------------|--------------|
| `oracle-sql-query` | `/oracle-sql-query` | Run any SQL — data queries, analysis, custom SELECT |
| `oracle-table-schema` | `/oracle-table-schema <table>` | Describe table columns and data types |
| `oracle-table-constraints` | `/oracle-table-constraints <table>` | Show PK, FK, and check constraints |
| `oracle-table-relationships` | `/oracle-table-relationships` | Map FK relationships across the schema |
| `oracle-search-tables` | `/oracle-search-tables <pattern>` | Find tables by name pattern |
| `oracle-search-columns` | `/oracle-search-columns <name>` | Find columns by name across all tables |
| `oracle-table-indexes` | `/oracle-table-indexes <table>` | Show indexes and indexed columns |
| `oracle-database-info` | `/oracle-database-info` | Database version, schema metadata, object counts |
| `oracle-export` | `/oracle-export` | Export query results to CSV or Excel via SQLcl SPOOL |

Skills aren't required — you can ask Claude database questions directly and it
will use the MCP tools on its own. Skills give Claude focused guidance for
specific task types, which improves accuracy and reduces back-and-forth.

### What a skill invocation looks like

```
/oracle-table-schema EMPLOYEES
```

Claude receives the skill's prompt template, connects to the database using
the `connect` MCP tool, runs `DESC EMPLOYEES` and queries the data dictionary,
then returns a formatted summary of columns, types, and nullability.

### Connect first

Before running any query, Claude needs to connect to the HR schema. Either
ask Claude directly — "connect to the hr_local connection" — or use a skill
that triggers a connect step automatically. The connection you saved in Part 1
(`hr_local`) is what Claude uses:

```
hr/HrUser_2026@//localhost:1521/XEPDB1
```

> ✅ Once connected in a chat session, Claude stays connected until you
> close the session or explicitly disconnect.

---

## Verify End-to-End

With the MCP server connected, run a quick smoke test:

1. In Claude Code chat, type:
   ```
   Connect to hr_local and tell me how many employees are in the database.
   ```

2. Claude should call `connect` then `sql_run`, and return something like:
   ```
   The HR schema has 107 employees.
   ```

If you see a live number instead of an error, the full stack is working:
Docker Oracle → SQLcl MCP → Claude Code.

---

## What's Next

Everything is wired up. In Part 3, you'll run real prompts against the live
HR database and see Claude query Oracle, explain relationships, and export data
— all in plain English.

→ [Part 3: Prompt Demos — Querying Oracle in Plain English](#)

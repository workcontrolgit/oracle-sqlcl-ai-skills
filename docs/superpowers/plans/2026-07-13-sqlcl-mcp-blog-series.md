# SQLcl MCP Claude Blog Series — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write a 3-part Medium blog series teaching developers how to connect Claude AI to Oracle Database using the SQLcl MCP server, using the Docker HR schema repo as a hands-on demo.

**Architecture:** Three standalone but linked articles — Part 1 covers tooling setup (extension + Docker), Part 2 covers MCP server configuration and Claude skills, Part 3 is a full prompt demo walkthrough against the HR schema. Each article is self-contained markdown, saved to `blogs/sqlcl-mcp-claude/`.

**Tech Stack:** SQLcl 24+ (bundled in VS Code Oracle SQL Developer extension), Claude Code, MCP stdio server protocol, Docker Oracle XE 21c, HR sample schema.

## Global Constraints

- All file paths in articles must use `<you>` and `<version>` placeholders for personal paths
- SQLcl connection string: `hr/HrUser_2026@//localhost:1521/XEPDB1`
- Docker image: Oracle XE from this repo's `docker-compose.yml`
- Tone: Developer-friendly, practical, minimal theory — show the outcome first, explain why second
- Each article ends with a "What's Next" link to the next part
- Every prompt demo must show both the user prompt and the Claude output
- Code blocks must specify language (powershell, sql, json, bash)
- No emojis unless for callout boxes (⚠️, 💡, ✅)

---

## File Structure

```
blogs/sqlcl-mcp-claude/
  part-1-setup.md          — Install extension, spin up Docker HR schema
  part-2-mcp-skills.md     — Configure MCP server, install Claude skills
  part-3-prompt-demos.md   — Full prompt walkthroughs against live HR DB
```

---

## Task 1: Part 1 — Setup: VS Code Extension + Docker Oracle HR Schema

**File:** Create `blogs/sqlcl-mcp-claude/part-1-setup.md`

**Covers:**
- What this series builds (1 paragraph intro with outcome screenshot description)
- What SQLcl is and why it matters for AI tooling
- Installing the Oracle SQL Developer extension in VS Code
- Finding the SQLcl binary path after install
- Cloning the demo repo
- Spinning up Oracle XE with Docker Compose
- Verifying the HR schema is ready
- Saving the HR connection in SQLcl

- [ ] **Step 1: Write article intro and overview section**

```markdown
# Talk to Oracle with Claude AI — Part 1: Setup

The Oracle SQL Developer extension for VS Code ships with a full SQLcl binary.
That binary includes a built-in MCP server — which means Claude AI can talk
directly to your Oracle database without any middleware, scripts, or API wrappers.

By the end of this series, you'll type a plain-English question in Claude and
get back live Oracle data. This first part gets the tooling running.

**Series:**
- Part 1: Setup — VS Code extension, Docker HR schema ← you are here
- Part 2: MCP Server Configuration + Claude Skills
- Part 3: Prompt Demos — Querying Oracle in Plain English
```

- [ ] **Step 2: Write "What is SQLcl?" section**

```markdown
## What is SQLcl?

SQLcl (SQL Developer Command Line) is Oracle's modern CLI replacement for SQL*Plus.
It supports scripting, Liquibase migrations, and — since version 24 — a built-in
**MCP server** that exposes Oracle database tools over the Model Context Protocol.

This means AI clients that support MCP (like Claude Code) can use SQLcl as a
structured bridge to your Oracle database.

You don't need to install SQLcl separately. The VS Code Oracle SQL Developer
extension bundles it.
```

- [ ] **Step 3: Write "Install the VS Code Extension" section**

```markdown
## Install the Oracle SQL Developer Extension

1. Open VS Code
2. Go to the Extensions panel (`Ctrl+Shift+X`)
3. Search for **Oracle SQL Developer**
4. Install the extension published by **Oracle**

After install, SQLcl is available at:

```
C:\Users\<you>\.vscode\extensions\oracle.sql-developer-<version>-win32-x64\dbtools\sqlcl\bin\sql.exe
```

Verify it works:

```powershell
$SQLCL = "C:\Users\<you>\.vscode\extensions\oracle.sql-developer-<version>-win32-x64\dbtools\sqlcl\bin\sql.exe"
& $SQLCL -V
# Output: SQLcl: Release 26.x.x.x Production Build: ...
```

> 💡 SQLcl is not added to your system PATH. Always use the full path when calling it from scripts.
```

- [ ] **Step 4: Write "Clone the Demo Repo" section**

```markdown
## Clone the Demo Repo

This series uses a GitHub repo that provides a Docker Oracle XE instance
pre-loaded with the HR sample schema.

```bash
git clone https://github.com/<your-org>/oracle.git
cd oracle
```

The repo contains:
- `docker-compose.yml` — Oracle XE container config
- `init-scripts/` — HR schema SQL (tables, data, constraints)
- `start-scripts/` — Startup verification scripts
- `.mcp.json` — SQLcl MCP server config for Claude Code
- `.claude/skills/` — Claude AI skills for querying Oracle
```

- [ ] **Step 5: Write "Spin Up Oracle XE with Docker" section**

```markdown
## Spin Up Oracle XE with Docker

Prerequisites: Docker Desktop with Linux containers enabled.

```powershell
docker compose up -d
```

Follow logs until you see the database is ready:

```powershell
docker compose logs -f oracle
```

Wait for:
```
DATABASE IS READY TO USE!
```

This usually takes 2–3 minutes on first run (Oracle initializes the database files).

### What Gets Created

The init scripts automatically create:
- `HR` user with password `HrUser_2026`
- 7 tables: EMPLOYEES, DEPARTMENTS, JOBS, JOB_HISTORY, LOCATIONS, COUNTRIES, REGIONS
- Foreign key relationships and sample data

### Credentials

| User | Password | Notes |
|------|----------|-------|
| `HR` | `HrUser_2026` | Schema owner, use for queries |
| `SYSTEM` | `OracleSys_2026` | Admin, use for DBA operations |

Connection details:
- Host: `localhost`
- Port: `1521`
- Service: `XEPDB1`
```

- [ ] **Step 6: Write "Save the HR Connection in SQLcl" section**

```markdown
## Save the HR Connection in SQLcl

The SQLcl MCP server uses named saved connections — you connect by name, not
by typing credentials every time. Save the HR connection once:

```powershell
$SQLCL = "C:\Users\<you>\.vscode\extensions\oracle.sql-developer-<version>-win32-x64\dbtools\sqlcl\bin\sql.exe"

# Save the connection (only needs to be done once)
"conn -save hr_local -savepwd hr/HrUser_2026@//localhost:1521/XEPDB1`nexit" | & $SQLCL /nolog
```

Verify it connects:

```powershell
"conn -name hr_local`nSELECT user FROM dual;`nexit" | & $SQLCL /nolog
```

Expected output:
```
Connected.

USER
-------
HR
```

> ✅ The connection `hr_local` is now saved locally. Claude will use this name
> to connect when you ask it to query the database.
```

- [ ] **Step 7: Write "What's Next" footer**

```markdown
## What's Next

In Part 2, you'll configure the SQLcl MCP server so Claude Code can discover
and use it, then install the Oracle query skills that turn plain-English
prompts into live database results.

→ [Part 2: MCP Server Configuration + Claude Skills](#)
```

- [ ] **Step 8: Save the file and commit**

```bash
git add blogs/sqlcl-mcp-claude/part-1-setup.md
git commit -m "docs: add blog part 1 - VS Code extension and Docker HR schema setup"
```

---

## Task 2: Part 2 — MCP Server Configuration + Claude Skills

**File:** Create `blogs/sqlcl-mcp-claude/part-2-mcp-skills.md`

**Covers:**
- What MCP is (one paragraph — no deep dive)
- How the SQLcl MCP server works
- The `.mcp.json` config file explained
- How Claude Code discovers the MCP server
- Available Claude skills in the repo
- Running `/mcp` to verify the connection

- [ ] **Step 1: Write article intro**

```markdown
# Talk to Oracle with Claude AI — Part 2: MCP Server + Claude Skills

In Part 1 you installed the Oracle SQL Developer extension and spun up a
Docker Oracle HR database. Now you'll wire Claude Code to that database using
the SQLcl MCP server — and install the skills that let Claude query Oracle
with plain English.

**Series:**
- Part 1: Setup — VS Code extension, Docker HR schema
- Part 2: MCP Server Configuration + Claude Skills ← you are here
- Part 3: Prompt Demos — Querying Oracle in Plain English
```

- [ ] **Step 2: Write "What is MCP?" section**

```markdown
## What is MCP?

The **Model Context Protocol** (MCP) is an open standard that lets AI models
call external tools in a structured, type-safe way. Instead of writing bash
scripts that pipe SQL through Claude's context, MCP gives the AI a proper
tool interface — with named tools, typed parameters, and structured responses.

SQLcl 24+ ships with a built-in MCP server. When Claude Code connects to it,
Claude gets direct access to tools like `run-sql`, `connect`, and
`schema_information` — no scripting glue required.
```

- [ ] **Step 3: Write "Configure the MCP Server" section**

```markdown
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

### Load the MCP Server

After updating the path:

1. Open the project in VS Code
2. Press `Ctrl+Shift+P` → **Developer: Reload Window**
3. Start a new Claude Code chat
4. Run `/mcp` to verify

You should see:
```
sqlcl  ✓ connected
```

> 💡 If the server doesn't appear, check that your `command` path is correct
> and that the Oracle SQL Developer extension is installed.
```

- [ ] **Step 4: Write "Available MCP Tools" section**

```markdown
## Available SQLcl MCP Tools

Once connected, Claude has access to these tools:

| Tool | What it does |
|------|--------------|
| `connections_list` | List all saved Oracle connections |
| `connect` | Connect to a named saved connection |
| `schema_information` | Get schema overview (tables, object types) |
| `sql_run` | Execute SQL queries |
| `sqlcl_run` | Execute SQLcl commands (SET, DDL, Liquibase) |
| `disconnect` | Close the current connection |
| `request_status` | Check current connection status |

Claude uses these tools automatically when you ask database questions — you
don't call them directly.
```

- [ ] **Step 5: Write "Claude Skills" section**

```markdown
## Claude Skills — Plain English to Oracle

The repo's `.claude/skills/` folder contains **Claude AI skills** — pre-built
prompt templates that tell Claude which MCP tools to use for specific tasks.
They're invoked with a `/skill-name` command in the Claude chat.

| Skill | Invoke with | What it does |
|-------|-------------|--------------|
| `oracle-sql-query` | `/oracle-sql-query` | Run any SQL — data queries, analysis |
| `oracle-table-schema` | `/oracle-table-schema <table>` | Describe table columns and types |
| `oracle-table-constraints` | `/oracle-table-constraints <table>` | Show PK, FK, check constraints |
| `oracle-table-relationships` | `/oracle-table-relationships` | Map FK relationships across schema |
| `oracle-search-tables` | `/oracle-search-tables <pattern>` | Find tables by name pattern |
| `oracle-search-columns` | `/oracle-search-columns <name>` | Find columns across all tables |
| `oracle-table-indexes` | `/oracle-table-indexes <table>` | Show indexes and indexed columns |
| `oracle-database-info` | `/oracle-database-info` | Database version, schema metadata |
| `oracle-export` | `/oracle-export` | Export query results to CSV or Excel |

Skills aren't required — you can also ask Claude database questions directly
and it will use the MCP tools on its own. Skills just give Claude focused
guidance for specific tasks.
```

- [ ] **Step 6: Write "What's Next" footer**

```markdown
## What's Next

Everything is wired up. In Part 3, you'll run real prompts against the live
HR database and see Claude query Oracle, explain relationships, and export data
— all in plain English.

→ [Part 3: Prompt Demos — Querying Oracle in Plain English](#)
```

- [ ] **Step 7: Save and commit**

```bash
git add blogs/sqlcl-mcp-claude/part-2-mcp-skills.md
git commit -m "docs: add blog part 2 - MCP server configuration and Claude skills"
```

---

## Task 3: Part 3 — Prompt Demo Walkthrough

**File:** Create `blogs/sqlcl-mcp-claude/part-3-prompt-demos.md`

**Covers:**
- Connecting Claude to the HR schema with a single prompt
- Exploring the schema
- Querying employees data
- Understanding table relationships
- Viewing constraints
- Exporting data to CSV
- A "what can you ask?" prompt reference at the end

Each demo shows: the exact user prompt → the Claude response summary → the SQL Claude ran → the result.

- [ ] **Step 1: Write article intro**

```markdown
# Talk to Oracle with Claude AI — Part 3: Prompt Demos

Parts 1 and 2 set up the tooling. Now it's time to use it. This part walks
through real prompts against the live Docker HR schema — showing exactly what
you type, what Claude does, and what comes back.

All demos use the `hr_local` connection to the Docker Oracle XE database
from Part 1.

**Series:**
- Part 1: Setup — VS Code extension, Docker HR schema
- Part 2: MCP Server Configuration + Claude Skills
- Part 3: Prompt Demos — Querying Oracle in Plain English ← you are here
```

- [ ] **Step 2: Write "Connect to the Database" demo**

```markdown
## Demo 1: Connect to the Database

**You type:**
```
connect to oracle hr schema
```

**What Claude does:** Calls `connections_list` to find saved connections,
then calls `connect` with `hr_local`, then calls `schema_information`.

**Claude responds:**
```
Connected to Oracle 21.3.0.0.0 as HR (hr_local).

HR schema objects:

Tables (8): EMPLOYEES, DEPARTMENTS, JOBS, JOB_HISTORY,
            LOCATIONS, COUNTRIES, REGIONS, DBTOOLS$MCP_LOG
```

One prompt. No connection string. No credentials in the chat.
```

- [ ] **Step 3: Write "Show Schema" demo**

```markdown
## Demo 2: Explore the Schema

**You type:**
```
show schema
```

**What Claude does:** Calls `schema_information` and presents the results.

**Result:**

| Object Type | Objects |
|-------------|---------|
| TABLE | EMPLOYEES, DEPARTMENTS, JOBS, JOB_HISTORY, LOCATIONS, COUNTRIES, REGIONS |
| INDEX | 9 indexes |
| SEQUENCE | 1 sequence |

Claude organizes and explains the schema — you don't need to know which
system views to query.
```

- [ ] **Step 4: Write "Query Employees" demo**

```markdown
## Demo 3: Query the Employees Table

**You type:**
```
show me records in employees table
```

**SQL Claude runs:**
```sql
SELECT EMPLOYEE_ID, FIRST_NAME, LAST_NAME, JOB_ID, SALARY, DEPARTMENT_ID
FROM employees
ORDER BY EMPLOYEE_ID
```

**Result:**

| ID | Name | Job | Salary | Dept |
|----|------|-----|--------|------|
| 100 | Steven King | AD_PRES | 24,000 | 10 |
| 101 | Neena Kochhar | AD_VP | 17,000 | 10 |
| 102 | Lex De Haan | AD_VP | 17,000 | 10 |
| 103 | Alexander Hunold | IT_PROG | 9,000 | 60 |
| 104 | Bruce Ernst | IT_PROG | 6,000 | 60 |

You asked in plain English. Claude figured out the table name, column
selection, and ordering.
```

- [ ] **Step 5: Write "Table Constraints" demo**

```markdown
## Demo 4: Understand Table Constraints

**You type:**
```
oracle-table-constraints employees
```

**SQL Claude runs:**
```sql
SELECT uc.constraint_name, uc.constraint_type, ucc.column_name,
       uc.r_constraint_name, uc.search_condition
FROM user_constraints uc
JOIN user_cons_columns ucc ON uc.constraint_name = ucc.constraint_name
WHERE uc.table_name = 'EMPLOYEES'
ORDER BY uc.constraint_type, uc.constraint_name, ucc.position
```

**Claude explains:**

| Constraint | Type | Column | Details |
|---|---|---|---|
| SYS_C008318 | Primary Key | EMPLOYEE_ID | |
| SYS_C008319 | Unique | EMAIL | |
| FK_EMPLOYEES_DEPT | Foreign Key | DEPARTMENT_ID | → DEPARTMENTS |
| FK_EMPLOYEES_JOB | Foreign Key | JOB_ID | → JOBS |
| FK_EMPLOYEES_MGR | Foreign Key | MANAGER_ID | → EMPLOYEES (self) |

> 💡 `FK_EMPLOYEES_MGR` is a self-referencing foreign key — `MANAGER_ID`
> points back to `EMPLOYEE_ID` on the same table. Claude calls this out.
```

- [ ] **Step 6: Write "Table Relationships" demo**

```markdown
## Demo 5: Map the Full Schema Relationships

**You type:**
```
oracle-table-relationships
```

**What Claude does:** Queries `user_constraints` with FK joins across all
tables, then draws a relationship hierarchy.

**Claude responds:**

```
REGIONS
  └── COUNTRIES.REGION_ID

COUNTRIES
  └── LOCATIONS.COUNTRY_ID

LOCATIONS
  └── DEPARTMENTS.LOCATION_ID

DEPARTMENTS
  ├── EMPLOYEES.DEPARTMENT_ID
  └── JOB_HISTORY.DEPARTMENT_ID

JOBS
  ├── EMPLOYEES.JOB_ID
  └── JOB_HISTORY.JOB_ID

EMPLOYEES ──(self)── EMPLOYEES.MANAGER_ID → EMPLOYEE_ID
  └── JOB_HISTORY.EMPLOYEE_ID
```

One prompt gives you a complete picture of the HR schema hierarchy — the
kind of diagram that would take 20 minutes to write manually.
```

- [ ] **Step 7: Write "Export to CSV" demo**

```markdown
## Demo 6: Export Query Results

**You type:**
```
export employees to csv
```

**What Claude does:** Uses the `oracle-export` skill, which runs SQLcl's
`SPOOL` command with `SQLFORMAT csv`.

**SQLcl commands Claude runs:**
```sql
SET SQLFORMAT csv
SPOOL employees_export.csv
SELECT * FROM employees;
SPOOL OFF
SET SQLFORMAT default
```

**Result:** `employees_export.csv` created in the project directory with
all employee records in standard CSV format — ready for Excel, Pandas,
or any data tool.
```

- [ ] **Step 8: Write "Prompt Reference" section**

```markdown
## Prompt Reference

Here are prompts you can use directly against the HR schema:

### Schema Exploration
```
show schema
oracle-table-relationships
oracle-search-tables EMP
oracle-search-columns SALARY
```

### Table Details
```
oracle-table-schema employees
oracle-table-constraints employees
oracle-table-indexes employees
```

### Data Queries
```
show me all employees in department 60
what is the average salary by department?
who are the managers (employees with direct reports)?
show me job history for employee 101
```

### Export
```
export employees to csv
export departments to excel
```

### Database Info
```
what oracle version is this?
show me all users in the database
```

> 💡 You don't need the skill name prefix for most queries — Claude will
> use the right MCP tools automatically. The skill prefix (`oracle-table-schema`)
> gives Claude focused guidance for schema-specific tasks.
```

- [ ] **Step 9: Write closing section**

```markdown
## Wrapping Up

This series showed how to:

1. Install SQLcl via the Oracle SQL Developer VS Code extension
2. Spin up a local Oracle HR schema with Docker
3. Configure Claude Code to use the SQLcl MCP server
4. Query Oracle in plain English using Claude skills

The pattern works for any Oracle database — swap the Docker connection
for your dev, staging, or prod instance and the same skills and prompts apply.

The full source — Docker setup, `.mcp.json`, and all Claude skills — is
available at: [github.com/<your-org>/oracle](#)
```

- [ ] **Step 10: Save and commit**

```bash
git add blogs/sqlcl-mcp-claude/part-3-prompt-demos.md
git commit -m "docs: add blog part 3 - prompt demo walkthrough against HR schema"
```

---

## Self-Review

### Spec Coverage

| Requirement | Covered in |
|---|---|
| Install Oracle SQL Developer extension | Part 1, Step 3 |
| Configure MCP server | Part 2, Step 3 |
| Use skills to let Claude talk to Oracle | Part 2, Steps 4–5 |
| Docker HR schema setup instructions | Part 1, Steps 4–6 |
| Prompt demos with user prompt + output | Part 3, Steps 2–8 |
| Prompt reference for copy-paste use | Part 3, Step 8 |
| Series linking between articles | All parts, "What's Next" sections |

### Placeholder Scan ✅

No TBD, TODO, or "implement later" entries. All code blocks include actual
content. All prompts show both input and output.

### Consistency Check ✅

- Connection name `hr_local` used consistently across all 3 parts
- SQLcl path format `C:\Users\<you>\...` consistent across all references
- Skill names match `.claude/skills/` directory names exactly
- Docker credentials match `docker-compose.yml` and `init-scripts/`

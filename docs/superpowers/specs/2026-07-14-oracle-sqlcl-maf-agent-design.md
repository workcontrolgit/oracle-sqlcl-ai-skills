# Design: Oracle SQLcl MAF Agent

**Date:** 2026-07-14
**Status:** Approved

---

## Goal

Build a standalone C# console application that uses Microsoft Agent Framework (MAF)
skills and the SQLcl MCP server to let a user query an Oracle HR database in
plain English.

The demo accompanies the blog series in `blogs/sqlcl-mcp-claude/` and is the
code reference for Part 4 (Microsoft Agent Framework).

---

## Location

```
C:\apps\oracle\
└── src\
    └── OracleSqlclAgent\
        ├── OracleSqlclAgent.csproj
        ├── appsettings.json
        ├── appsettings.Development.json   ← gitignored, holds API keys
        ├── Program.cs
        ├── OracleAgent.cs
        └── Skills\
            ├── OracleSqlQuerySkill.cs
            ├── OracleTableSchemaSkill.cs
            ├── OracleTableConstraintsSkill.cs
            ├── OracleTableRelationshipsSkill.cs
            └── OracleDatabaseInfoSkill.cs
```

Blog files remain in `blogs/sqlcl-mcp-claude/` — source and docs are kept separate.

---

## Packages

| Package | Purpose |
|---|---|
| `Microsoft.AgentFramework.Skills` | `AgentClassSkill`, `AgentSkillsProvider` |
| `ModelContextProtocol` | `McpClient`, `StdioClientTransport` |
| `Microsoft.Extensions.AI` | `IChatClient`, `AITool`, `ChatMessage` |
| `Microsoft.Extensions.AI.Anthropic` | Claude provider adapter |
| `Anthropic` | Anthropic API client |
| `OllamaSharp` | Ollama provider |
| `Spectre.Console` | TUI spinner, colored output |
| `Microsoft.Extensions.Configuration.*` | appsettings.json + user secrets |
| `Serilog` + `Serilog.Sinks.File` | Error-only file logging |

Target framework: `net10.0`

---

## Configuration

**`appsettings.json`** (committed — no secrets):

```json
{
  "AI": {
    "Provider": "Anthropic",
    "Anthropic": {
      "Model": "claude-opus-4-6"
    },
    "Ollama": {
      "Endpoint": "http://localhost:11434",
      "Model": "llama3.2"
    }
  },
  "SqlclMcp": {
    "Path": "C:\\Users\\<you>\\.vscode\\extensions\\oracle.sql-developer-<version>-win32-x64\\dbtools\\sqlcl\\bin\\sql.exe"
  }
}
```

**`appsettings.Development.json`** (gitignored — holds secrets):

```json
{
  "AI": {
    "Anthropic": { "ApiKey": "sk-ant-..." }
  }
}
```

Provider selection: `AI:Provider` = `"Anthropic"` or `"Ollama"`.
API key for Anthropic: `AI:Anthropic:ApiKey` (user secrets or env var).

---

## Skills

Five `AgentClassSkill` classes in `Skills/`. Each exposes:
- `Name` — slug used by MAF for matching
- `Description` — injected into system prompt (~1 sentence, ~20 tokens each)
- `Instructions` — full guidance loaded by MAF when a task matches (~200–400 tokens each)

All skills share `connection_name = "hr_local"` hardcoded in instructions.

| Class | Name | Description |
|---|---|---|
| `OracleSqlQuerySkill` | `oracle-sql-query` | Run any SQL — data queries, analysis, custom SELECT |
| `OracleTableSchemaSkill` | `oracle-table-schema` | Describe table columns, data types, nullability |
| `OracleTableConstraintsSkill` | `oracle-table-constraints` | Show PK, FK, unique, and check constraints for a table |
| `OracleTableRelationshipsSkill` | `oracle-table-relationships` | Map FK relationships across the full schema |
| `OracleDatabaseInfoSkill` | `oracle-database-info` | Database version and schema object counts |

### Skill instruction pattern (all five follow this structure):

```
## <Skill Name>

Use this skill when the user asks about <topic>.

Steps:
1. Call `connect` with connection_name = "hr_local"
2. <skill-specific SQL and formatting guidance>
3. Present results in plain text (no markdown tables — Medium target)
4. Call `disconnect` when done
```

### Registration

All five skills are registered with `AgentSkillsProvider` in `Program.cs` and
passed as a context provider to `OracleAgent`. MAF advertises skill names and
descriptions in the system prompt and loads full instructions on demand.

---

## OracleAgent.cs

Mirrors `HrAgent.cs` from `DotnetMcpTutorial/DotnetAiAgentMcp/src/HrMcp.Agent/`.

**Constructor:** `IChatClient chatClient, IList<AITool> tools, AgentSkillsProvider skills, UiStyle style`

**Methods:**
- `RunAsync(CancellationToken)` — console REPL: read input → `AskAsync` → render response → loop
- `AskAsync(string, CancellationToken)` — single-turn: append to history → `RunToolLoopAsync` → return text
- `RunToolLoopAsync(CancellationToken)` — `GetResponseAsync` loop until no `FunctionCallContent` blocks remain

**System prompt** (hardcoded constant):
```
You are an Oracle database assistant.
The database connection name is hr_local.
Always connect before running any query.
Use the available skills when they match the user's request.
Present results in plain text — do not use markdown tables.
```

**UI:** `UiStyle.Structured` (default) using Spectre.Console — same three styles
(`Structured`, `Minimal`, `Panels`) as `HrAgent`. Style picker shown at startup
with 2-second timeout defaulting to `Structured`.

---

## Program.cs Bootstrap Sequence

```
1. Load config:
   appsettings.json
   → appsettings.{DOTNET_ENVIRONMENT}.json
   → user secrets
   → environment variables

2. Configure Serilog (error-only file log → logs/error-*.log)

3. Start SQLcl MCP server:
   StdioClientTransport { Command = SqlclMcp:Path, Arguments = ["-mcp"] }
   McpClient.CreateAsync(transport)

4. Enumerate tools:
   mcpClient.ListToolsAsync() → IList<AITool>

5. Register skills:
   new AgentSkillsProvider()
   .Register(new OracleSqlQuerySkill())
   ... (all five)

6. Create IChatClient:
   if AI:Provider == "Anthropic" → AnthropicClient().AsIChatClient(model)
   if AI:Provider == "Ollama"    → OllamaApiClient(endpoint, model).AsIChatClient()

7. Print startup banner (provider, model, tool count, skill count)

8. Show UI style picker (2s timeout → Structured)

9. new OracleAgent(chatClient, tools, skills, style).RunAsync()
```

---

## Error Handling

- SQLcl path missing or invalid → `InvalidOperationException` with clear message at startup
- MCP server fails to start → exception surfaces with stderr captured from SQLcl process
- Tool call exception → caught in tool loop, surfaced as tool result string `"Error: <message>"`
- Unhandled top-level exception → logged via Serilog to `logs/error-*.log`, exit code 1

---

## .gitignore additions

```
src/OracleSqlclAgent/appsettings.Development.json
src/OracleSqlclAgent/logs/
src/OracleSqlclAgent/bin/
src/OracleSqlclAgent/obj/
```

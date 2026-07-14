# Talk to Oracle with an AI Agent — Part 4: Microsoft Agent Framework

Parts 1–3 showed how Claude Code talks to Oracle through the SQLcl MCP server
using built-in skills. This part builds a standalone C# application that does
the same thing using **Microsoft Agent Framework (MAF)** — Microsoft's unified
AI agent SDK that reached 1.0 GA in April 2026.

The result: a .NET console app where you type a plain-English question and an
AI agent queries your local Oracle HR database and answers you.

**Series:**
- Part 1: Setup — VS Code extension, Docker HR schema
- Part 2: MCP Server Configuration + Claude Skills
- Part 3: Prompt Demos — Querying Oracle in Plain English
- Part 4: Microsoft Agent Framework ← you are here

← [Part 3: Prompt Demos](#)

---

## What is Microsoft Agent Framework?

MAF is the unified successor to both **AutoGen** and **Semantic Kernel**
(both are now in maintenance mode). It gives you a clean programming model
for building AI agents in C# and Python — chat clients, tools, MCP
integrations, context providers, and multi-agent workflows — without writing
the orchestration plumbing yourself.

MAF connects to MCP servers natively. That means it can talk directly to
`sqlcl -mcp` the same way Claude Code does — no subprocess wiring, no manual
tool definitions, no agentic loop to maintain.

---

## Prerequisites

- Docker Desktop with the Oracle HR container running (from Part 1)
- `hr_local` saved connection in SQLcl (from Part 1)
- .NET 9 SDK
- An Anthropic API key

---

## Create the Project

```bash
mkdir OracleAgent
cd OracleAgent
dotnet new console
```

Install the packages:

```bash
dotnet add package Microsoft.AgentFramework
dotnet add package Microsoft.AgentFramework.Skills
dotnet add package ModelContextProtocol
dotnet add package Anthropic
```

---

## Connect MAF to the SQLcl MCP Server

MAF uses the `ModelContextProtocol` NuGet package to connect to any MCP
server over stdio. The SQLcl binary exposes all its database tools
(`connect`, `sql_run`, `schema_information`, `disconnect`, etc.) over
that channel automatically when you pass `-mcp`.

```csharp
using Microsoft.AgentFramework;
using Microsoft.Extensions.AI;
using ModelContextProtocol.Client;
using ModelContextProtocol.Protocol.Transport;
using Anthropic;

// Path to SQLcl bundled with the VS Code Oracle SQL Developer extension
var sqlclPath = @"C:\Users\<you>\.vscode\extensions\oracle.sql-developer-<version>-win32-x64\dbtools\sqlcl\bin\sql.exe";

// Start the SQLcl MCP server as a subprocess over stdio
await using var mcpClient = await McpClientFactory.CreateAsync(
    new StdioClientTransport(new StdioClientTransportOptions
    {
        Name = "sqlcl",
        Command = sqlclPath,
        Arguments = ["-mcp"],
    }));

// Enumerate MCP tools — MAF converts them to AITool objects automatically
var mcpTools = new List<McpClientTool>();
await foreach (var tool in mcpClient.EnumerateToolsAsync())
    mcpTools.Add(tool);

Console.WriteLine($"SQLcl MCP tools loaded: {string.Join(", ", mcpTools.Select(t => t.Name))}");
```

When this runs you'll see:

```
SQLcl MCP tools loaded: connections_list, connect, disconnect, sql_run, sqlcl_run, schema_information, request_status
```

These are the same tools Claude Code uses — MAF just discovered them from
the running MCP server.

---

## Build the Agent

MAF's `ChatAgent` wraps a chat model and a list of tools. It runs the
agentic loop internally — calling tools, feeding results back, and looping
until the model stops requesting tools.

```csharp
// Anthropic client via Microsoft.Extensions.AI abstraction
IChatClient chatClient = new AnthropicClient()
    .AsIChatClient("claude-opus-4-6");

// Create the agent with the SQLcl MCP tools
var agent = chatClient.CreateAIAgent(
    instructions: """
        You are an Oracle database assistant.
        The database connection name is hr_local.
        Always connect before running any query.
        Format query results clearly for the user.
        """,
    tools: mcpTools.Cast<AITool>().ToArray()
);

// Run a query
Console.Write("Ask a question: ");
var question = Console.ReadLine()!;

var response = await agent.InvokeAsync(question);
Console.WriteLine(response.Text);
```

That's the full agent. MAF handles:
- Calling `connect` with `hr_local` when it needs to connect
- Running `sql_run` with the appropriate SQL
- Looping until the model returns a final answer

---

## Add Oracle Skills

MAF has a native **Agent Skills** system — modular prompt packages that give
the agent focused expertise for specific task types. Skills follow a
three-phase pattern:

1. **Advertise** — skill names and descriptions (~100 tokens) are injected
   into the system prompt so the agent knows what's available
2. **Load** — when a task matches, the agent loads the full skill instructions
3. **Read resources** — supplementary files are fetched only when needed

This mirrors how the `.claude/skills/` folder works in Claude Code, but
MAF skills are first-class SDK objects.

### Define Oracle Skills as Classes

```csharp
using Microsoft.AgentFramework.Skills;

public class OracleSqlQuerySkill : AgentClassSkill
{
    public override string Name => "oracle-sql-query";
    public override string Description =>
        "Run any SQL query against Oracle — SELECT, schema exploration, data analysis";

    protected override string Instructions => """
        ## Oracle SQL Query

        Use this skill when the user asks to query Oracle data.

        Steps:
        1. Call `connect` with connection_name = "hr_local"
        2. Build the appropriate SQL based on the user's request
        3. Call `sql_run` with the SQL
        4. Format the results clearly — use plain text, not markdown tables
        5. Call `disconnect` when done
        """;
}

public class OracleTableSchemaSkill : AgentClassSkill
{
    public override string Name => "oracle-table-schema";
    public override string Description =>
        "Describe Oracle table structure — columns, data types, nullability";

    protected override string Instructions => """
        ## Oracle Table Schema

        Use this skill when the user asks about a table's structure or columns.

        Steps:
        1. Call `connect` with connection_name = "hr_local"
        2. Run: SELECT column_name, data_type, nullable, data_length
                 FROM user_tab_columns
                 WHERE table_name = UPPER('<table>')
                 ORDER BY column_id
        3. Present columns with type and nullability
        4. Call `disconnect` when done
        """;
}

public class OracleTableRelationshipsSkill : AgentClassSkill
{
    public override string Name => "oracle-table-relationships";
    public override string Description =>
        "Map foreign key relationships across the Oracle schema";

    protected override string Instructions => """
        ## Oracle Table Relationships

        Use this skill when the user asks about table relationships or schema structure.

        Steps:
        1. Call `connect` with connection_name = "hr_local"
        2. Run: SELECT uc.constraint_name, uc.table_name, ucc.column_name,
                        uc.r_constraint_name,
                        (SELECT table_name FROM user_constraints
                         WHERE constraint_name = uc.r_constraint_name) AS ref_table
                 FROM user_constraints uc
                 JOIN user_cons_columns ucc ON uc.constraint_name = ucc.constraint_name
                 WHERE uc.constraint_type = 'R'
                 ORDER BY uc.table_name
        3. Draw a relationship hierarchy showing parent → child tables
        4. Call `disconnect` when done
        """;
}
```

### Register Skills with the Agent

```csharp
using Microsoft.AgentFramework.Skills;

// Register skills with the provider
var skillProvider = new AgentSkillsProvider();
skillProvider.Register(new OracleSqlQuerySkill());
skillProvider.Register(new OracleTableSchemaSkill());
skillProvider.Register(new OracleTableRelationshipsSkill());

// Build the agent with MCP tools + skill provider
var agent = chatClient.CreateAIAgent(
    instructions: """
        You are an Oracle database assistant.
        The database connection name is hr_local.
        Use the available skills when they match the user's request.
        Always connect before running any query.
        Format results in plain text — do not use markdown tables.
        """,
    tools: mcpTools.Cast<AITool>().ToArray(),
    contextProviders: [skillProvider]
);
```

When the user asks a question that matches a skill, MAF automatically loads
the skill's full instructions into context before the agent responds.

---

## Full Program

```csharp
using Microsoft.AgentFramework;
using Microsoft.AgentFramework.Skills;
using Microsoft.Extensions.AI;
using ModelContextProtocol.Client;
using ModelContextProtocol.Protocol.Transport;
using Anthropic;

var sqlclPath = @"C:\Users\<you>\.vscode\extensions\oracle.sql-developer-<version>-win32-x64\dbtools\sqlcl\bin\sql.exe";

// Start SQLcl MCP server
await using var mcpClient = await McpClientFactory.CreateAsync(
    new StdioClientTransport(new StdioClientTransportOptions
    {
        Name = "sqlcl",
        Command = sqlclPath,
        Arguments = ["-mcp"],
    }));

var mcpTools = new List<McpClientTool>();
await foreach (var tool in mcpClient.EnumerateToolsAsync())
    mcpTools.Add(tool);

// Register skills
var skillProvider = new AgentSkillsProvider();
skillProvider.Register(new OracleSqlQuerySkill());
skillProvider.Register(new OracleTableSchemaSkill());
skillProvider.Register(new OracleTableRelationshipsSkill());

// Build agent
IChatClient chatClient = new AnthropicClient()
    .AsIChatClient("claude-opus-4-6");

var agent = chatClient.CreateAIAgent(
    instructions: """
        You are an Oracle database assistant.
        The database connection name is hr_local.
        Use the available skills when they match the user's request.
        Always connect before running any query.
        Format results in plain text — do not use markdown tables.
        """,
    tools: mcpTools.Cast<AITool>().ToArray(),
    contextProviders: [skillProvider]
);

// Conversation loop
Console.WriteLine("Oracle Agent ready. Type a question or 'exit' to quit.\n");
while (true)
{
    Console.Write("> ");
    var input = Console.ReadLine()!;
    if (input.Equals("exit", StringComparison.OrdinalIgnoreCase)) break;

    var response = await agent.InvokeAsync(input);
    Console.WriteLine($"\n{response.Text}\n");
}
```

---

## Example Prompts

Try these against the running agent:

```
connect to oracle hr schema
show me records in employees table
what is the schema of the employees table?
map the foreign key relationships in the schema
what is the average salary by department?
who are the managers?
export employees to csv
```

---

## How Skills Compare: MAF vs Claude Code

Both MAF and Claude Code use skills as modular prompt packages that give
the agent focused expertise. The mechanisms are parallel:

**Claude Code skills** live in `.claude/skills/<name>/SKILL.md` and are
invoked with `/skill-name` in the chat. The Claude Code harness advertises
available skills, loads them on demand, and injects them into context.

**MAF skills** are C# classes (or SKILL.md files in a folder) registered
with `AgentSkillsProvider`. MAF advertises skill names and descriptions in
the system prompt, then loads the full instructions when a task matches.

The key difference: Claude Code skills run inside Claude Code's harness.
MAF skills run inside your own C# application — you own the agent, the
deployment, and the runtime.

---

## What's Next

This agent runs locally against Docker Oracle XE. To point it at a
different database, save a new named connection in SQLcl and update
the `connection_name` in the skill instructions. No code changes needed.

The full source — Docker setup, `.mcp.json`, Claude skills, and this MAF
agent — is available at:
[github.com/workcontrolgit/oracle-sqlcl-ai-skills](https://github.com/workcontrolgit/oracle-sqlcl-ai-skills)

# OracleSqlclAgent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone C# .NET console app (`OracleSqlclAgent`) that uses MAF `AgentClassSkill` classes and the SQLcl MCP server to let a user query an Oracle HR database in plain English.

**Architecture:** A manual agentic loop (mirrors `HrAgent` from `DotnetMcpTutorial`) wraps an `IChatClient` and `IList<AITool>` from the SQLcl MCP server. Five `AgentClassSkill` subclasses provide structured Oracle instructions. Multi-provider: Anthropic or Ollama selected via `appsettings.json`.

**Tech Stack:** .NET 10, `Microsoft.AgentFramework.Skills`, `ModelContextProtocol`, `Microsoft.Extensions.AI`, `Anthropic`, `OllamaSharp`, `Spectre.Console`, `Serilog`

## Global Constraints

- Target framework: `net10.0`
- Connection name hardcoded in all skill instructions: `hr_local`
- All model output: plain text only — no markdown tables
- API key in `appsettings.Development.json` (gitignored) — never committed
- Skill class property `Instructions` is `protected override string`
- Five skills only: oracle-sql-query, oracle-table-schema, oracle-table-constraints, oracle-table-relationships, oracle-database-info
- Reference pattern: `c:\apps\DotnetMcpTutorial\DotnetAiAgentMcp\src\HrMcp.Agent\HrAgent.cs`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `src/OracleSqlclAgent/OracleSqlclAgent.csproj` | Create | Package references, net10.0 target |
| `src/OracleSqlclAgent/appsettings.json` | Create | Non-secret config (provider, model, SQLcl path) |
| `src/OracleSqlclAgent/appsettings.Development.json` | Create (gitignored) | API key template |
| `src/OracleSqlclAgent/Skills/OracleSqlQuerySkill.cs` | Create | SQL query instructions |
| `src/OracleSqlclAgent/Skills/OracleTableSchemaSkill.cs` | Create | Column/type inspection instructions |
| `src/OracleSqlclAgent/Skills/OracleTableConstraintsSkill.cs` | Create | PK/FK/check constraint instructions |
| `src/OracleSqlclAgent/Skills/OracleTableRelationshipsSkill.cs` | Create | FK hierarchy instructions |
| `src/OracleSqlclAgent/Skills/OracleDatabaseInfoSkill.cs` | Create | Version/object-count instructions |
| `src/OracleSqlclAgent/OracleAgent.cs` | Create | REPL loop, manual tool loop, Spectre.Console TUI |
| `src/OracleSqlclAgent/Program.cs` | Create | Bootstrap: config → MCP → skills → IChatClient → agent |
| `.gitignore` | Modify | Add entries for new src/ paths |

---

## Task 1: Project Scaffold

**Files:**
- Create: `src/OracleSqlclAgent/OracleSqlclAgent.csproj`
- Create: `src/OracleSqlclAgent/appsettings.json`
- Create: `src/OracleSqlclAgent/appsettings.Development.json`
- Modify: `.gitignore`

**Interfaces:**
- Produces: compilable project that `dotnet restore` and `dotnet build` succeed on

- [ ] **Step 1: Create project directory**

```bash
mkdir -p src/OracleSqlclAgent/Skills
```

- [ ] **Step 2: Write `OracleSqlclAgent.csproj`**

Create `src/OracleSqlclAgent/OracleSqlclAgent.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <RootNamespace>OracleSqlclAgent</RootNamespace>
    <AssemblyName>OracleSqlclAgent</AssemblyName>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.AgentFramework.Skills" Version="*" />
    <PackageReference Include="ModelContextProtocol" Version="*" />
    <PackageReference Include="Microsoft.Extensions.AI" Version="*" />
    <PackageReference Include="Microsoft.Extensions.AI.Anthropic" Version="*" />
    <PackageReference Include="Anthropic" Version="*" />
    <PackageReference Include="OllamaSharp" Version="*" />
    <PackageReference Include="Spectre.Console" Version="*" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="*" />
    <PackageReference Include="Microsoft.Extensions.Configuration.UserSecrets" Version="*" />
    <PackageReference Include="Microsoft.Extensions.Configuration.EnvironmentVariables" Version="*" />
    <PackageReference Include="Serilog" Version="*" />
    <PackageReference Include="Serilog.Sinks.File" Version="*" />
  </ItemGroup>
  <ItemGroup>
    <Content Include="appsettings.json" CopyToOutputDirectory="PreserveNewest" />
    <Content Include="appsettings.Development.json" CopyToOutputDirectory="PreserveNewest"
             Condition="Exists('appsettings.Development.json')" />
  </ItemGroup>
</Project>
```

> **Note on package names:** `Microsoft.AgentFramework.Skills` is the MAF skills package as of April 2026 GA. If `dotnet restore` cannot find it, check NuGet for the current package name (may be `Microsoft.Agents.Skills` or similar) and update the reference.

- [ ] **Step 3: Write `appsettings.json`**

Create `src/OracleSqlclAgent/appsettings.json`:

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

- [ ] **Step 4: Write `appsettings.Development.json` template**

Create `src/OracleSqlclAgent/appsettings.Development.json`:

```json
{
  "AI": {
    "Anthropic": {
      "ApiKey": "sk-ant-..."
    }
  },
  "SqlclMcp": {
    "Path": "C:\\Users\\Fuji Nguyen\\.vscode\\extensions\\oracle.sql-developer-<version>-win32-x64\\dbtools\\sqlcl\\bin\\sql.exe"
  }
}
```

- [ ] **Step 5: Add `.gitignore` entries**

Open `.gitignore` at the repo root and append:

```
# OracleSqlclAgent
src/OracleSqlclAgent/appsettings.Development.json
src/OracleSqlclAgent/logs/
src/OracleSqlclAgent/bin/
src/OracleSqlclAgent/obj/
```

- [ ] **Step 6: Create a minimal `Program.cs` placeholder so the project compiles**

Create `src/OracleSqlclAgent/Program.cs`:

```csharp
// Placeholder — replaced in Task 4
Console.WriteLine("OracleSqlclAgent");
```

- [ ] **Step 7: Run restore and build**

```bash
cd src/OracleSqlclAgent
dotnet restore
dotnet build
```

Expected: `Build succeeded.`

If `Microsoft.AgentFramework.Skills` is not found, search NuGet:
```bash
dotnet package search AgentFramework.Skills
```
Update the package name in the `.csproj` accordingly.

- [ ] **Step 8: Commit**

```bash
git add src/OracleSqlclAgent/ .gitignore
git commit -m "feat: scaffold OracleSqlclAgent project"
```

---

## Task 2: Five AgentClassSkill Classes

**Files:**
- Create: `src/OracleSqlclAgent/Skills/OracleSqlQuerySkill.cs`
- Create: `src/OracleSqlclAgent/Skills/OracleTableSchemaSkill.cs`
- Create: `src/OracleSqlclAgent/Skills/OracleTableConstraintsSkill.cs`
- Create: `src/OracleSqlclAgent/Skills/OracleTableRelationshipsSkill.cs`
- Create: `src/OracleSqlclAgent/Skills/OracleDatabaseInfoSkill.cs`

**Interfaces:**
- Consumes: `AgentClassSkill` from `Microsoft.AgentFramework.Skills`
- Produces: five concrete skill classes, each exposing `Name` (string), `Description` (string), `Instructions` (protected string)

- [ ] **Step 1: Write `OracleSqlQuerySkill.cs`**

Create `src/OracleSqlclAgent/Skills/OracleSqlQuerySkill.cs`:

```csharp
using Microsoft.AgentFramework.Skills;

namespace OracleSqlclAgent.Skills;

public sealed class OracleSqlQuerySkill : AgentClassSkill
{
    public override string Name => "oracle-sql-query";

    public override string Description =>
        "Run any SQL query against Oracle — SELECT, aggregations, data analysis, custom queries.";

    protected override string Instructions => """
        ## Oracle SQL Query

        Use this skill when the user asks to query data, count records, calculate averages,
        or run any custom SQL against the Oracle HR schema.

        Steps:
        1. Call `connect` with connection_name = "hr_local"
        2. Build the appropriate SQL based on the user's request
        3. Call `sql_run` with the SQL
        4. Format the results in plain text — no markdown tables
        5. Call `disconnect` when done
        """;
}
```

- [ ] **Step 2: Write `OracleTableSchemaSkill.cs`**

Create `src/OracleSqlclAgent/Skills/OracleTableSchemaSkill.cs`:

```csharp
using Microsoft.AgentFramework.Skills;

namespace OracleSqlclAgent.Skills;

public sealed class OracleTableSchemaSkill : AgentClassSkill
{
    public override string Name => "oracle-table-schema";

    public override string Description =>
        "Describe Oracle table structure — columns, data types, nullability.";

    protected override string Instructions => """
        ## Oracle Table Schema

        Use this skill when the user asks about a table's columns, structure, or data types.

        Steps:
        1. Call `connect` with connection_name = "hr_local"
        2. Run:
           SELECT column_name, data_type, data_length, nullable
           FROM user_tab_columns
           WHERE table_name = UPPER('<table>')
           ORDER BY column_id
        3. Present each column with its type, length, and nullability (Y = optional, N = required)
        4. Call `disconnect` when done
        """;
}
```

- [ ] **Step 3: Write `OracleTableConstraintsSkill.cs`**

Create `src/OracleSqlclAgent/Skills/OracleTableConstraintsSkill.cs`:

```csharp
using Microsoft.AgentFramework.Skills;

namespace OracleSqlclAgent.Skills;

public sealed class OracleTableConstraintsSkill : AgentClassSkill
{
    public override string Name => "oracle-table-constraints";

    public override string Description =>
        "Show PK, FK, unique, and check constraints for an Oracle table.";

    protected override string Instructions => """
        ## Oracle Table Constraints

        Use this skill when the user asks about primary keys, foreign keys, unique constraints,
        or check constraints on a table.

        Steps:
        1. Call `connect` with connection_name = "hr_local"
        2. Run:
           SELECT uc.constraint_name, uc.constraint_type, ucc.column_name,
                  uc.r_constraint_name, uc.search_condition
           FROM user_constraints uc
           JOIN user_cons_columns ucc ON uc.constraint_name = ucc.constraint_name
           WHERE uc.table_name = UPPER('<table>')
           ORDER BY uc.constraint_type, uc.constraint_name, ucc.position
        3. Group results by constraint_type:
           - P = Primary Key
           - U = Unique
           - R = Foreign Key (r_constraint_name shows the referenced constraint)
           - C = Check / Not Null
        4. Present in plain text grouped by type, showing constraint name and column
        5. Call `disconnect` when done
        """;
}
```

- [ ] **Step 4: Write `OracleTableRelationshipsSkill.cs`**

Create `src/OracleSqlclAgent/Skills/OracleTableRelationshipsSkill.cs`:

```csharp
using Microsoft.AgentFramework.Skills;

namespace OracleSqlclAgent.Skills;

public sealed class OracleTableRelationshipsSkill : AgentClassSkill
{
    public override string Name => "oracle-table-relationships";

    public override string Description =>
        "Map all FK relationships across the Oracle HR schema as a hierarchy.";

    protected override string Instructions => """
        ## Oracle Table Relationships

        Use this skill when the user asks to map relationships, show schema hierarchy,
        or understand how tables are connected via foreign keys.

        Steps:
        1. Call `connect` with connection_name = "hr_local"
        2. Run:
           SELECT uc.table_name, ucc.column_name,
                  (SELECT table_name FROM user_constraints
                   WHERE constraint_name = uc.r_constraint_name) AS ref_table,
                  uc.r_constraint_name
           FROM user_constraints uc
           JOIN user_cons_columns ucc ON uc.constraint_name = ucc.constraint_name
           WHERE uc.constraint_type = 'R'
           ORDER BY ref_table, uc.table_name
        3. Group by ref_table (parent) and list child tables as indented entries:
           PARENT_TABLE
             └── CHILD_TABLE.COLUMN_NAME
        4. Note self-referencing FKs explicitly
           (e.g., EMPLOYEES ──(self)── EMPLOYEES.MANAGER_ID → EMPLOYEE_ID)
        5. Call `disconnect` when done
        """;
}
```

- [ ] **Step 5: Write `OracleDatabaseInfoSkill.cs`**

Create `src/OracleSqlclAgent/Skills/OracleDatabaseInfoSkill.cs`:

```csharp
using Microsoft.AgentFramework.Skills;

namespace OracleSqlclAgent.Skills;

public sealed class OracleDatabaseInfoSkill : AgentClassSkill
{
    public override string Name => "oracle-database-info";

    public override string Description =>
        "Show Oracle version, schema object counts, and database metadata.";

    protected override string Instructions => """
        ## Oracle Database Info

        Use this skill when the user asks about the Oracle version, what objects exist
        in the schema, or general database metadata.

        Steps:
        1. Call `connect` with connection_name = "hr_local"
        2. Run: SELECT banner FROM v$version WHERE banner LIKE 'Oracle%'
        3. Run:
           SELECT object_type, COUNT(*) AS cnt
           FROM user_objects
           GROUP BY object_type
           ORDER BY cnt DESC
        4. Present version string, then list object types with counts
        5. Call `disconnect` when done
        """;
}
```

- [ ] **Step 6: Build to verify all five classes compile**

```bash
cd src/OracleSqlclAgent
dotnet build
```

Expected: `Build succeeded.`

> **If `AgentClassSkill` is not found:** The actual base class may be in a differently named package or namespace. Check the NuGet package source for the MAF skills package and update `using` statements and the base class name accordingly. As a fallback, define a local abstract base class:
> ```csharp
> // LocalAgentClassSkill.cs — use only if MAF package unavailable
> namespace OracleSqlclAgent;
> public abstract class AgentClassSkill
> {
>     public abstract string Name { get; }
>     public abstract string Description { get; }
>     protected abstract string Instructions { get; }
>     public string GetInstructions() => Instructions;
> }
> ```

- [ ] **Step 7: Commit**

```bash
git add src/OracleSqlclAgent/Skills/
git commit -m "feat: add five OracleSqlclAgent skill classes"
```

---

## Task 3: OracleAgent.cs

**Files:**
- Create: `src/OracleSqlclAgent/OracleAgent.cs`

**Interfaces:**
- Consumes: `IChatClient`, `IList<AITool>`, `AgentSkillsProvider`, `UiStyle` (defined in this file)
- Produces: `OracleAgent` with `RunAsync(CancellationToken)` and `AskAsync(string, CancellationToken)`

- [ ] **Step 1: Write `OracleAgent.cs`**

Create `src/OracleSqlclAgent/OracleAgent.cs`:

```csharp
using Microsoft.AgentFramework.Skills;
using Microsoft.Extensions.AI;
using Spectre.Console;

namespace OracleSqlclAgent;

public enum UiStyle { Structured, Minimal, Panels }

public sealed class OracleAgent(
    IChatClient chatClient,
    IList<AITool> tools,
    AgentSkillsProvider skills,
    UiStyle style = UiStyle.Structured)
{
    private const string SystemPrompt = """
        You are an Oracle database assistant.
        The database connection name is hr_local.
        Always connect before running any query.
        Use the available skills when they match the user's request.
        Present results in plain text — do not use markdown tables.

        Available skills:
        - oracle-sql-query: Run any SQL query — SELECT, aggregations, data analysis
        - oracle-table-schema: Describe table columns, data types, nullability
        - oracle-table-constraints: Show PK, FK, unique, and check constraints for a table
        - oracle-table-relationships: Map FK relationships across the full schema
        - oracle-database-info: Database version and schema object counts
        """;

    private readonly List<ChatMessage> _history =
    [
        new(ChatRole.System, SystemPrompt)
    ];

    public async Task RunAsync(CancellationToken ct = default)
    {
        RenderWelcome();

        while (!ct.IsCancellationRequested)
        {
            var input = RenderUserPrompt();
            if (string.IsNullOrWhiteSpace(input)) continue;
            if (input.Equals("exit", StringComparison.OrdinalIgnoreCase)) break;

            _history.Add(new ChatMessage(ChatRole.User, input));

            var text = await RunToolLoopAsync(ct);
            RenderResponse(text);
        }
    }

    public async Task<string> AskAsync(string input, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(input))
            return string.Empty;

        _history.Add(new ChatMessage(ChatRole.User, input));
        return await RunToolLoopAsync(ct);
    }

    // ── Manual tool call loop ────────────────────────────────────────────────

    private async Task<string> RunToolLoopAsync(CancellationToken ct)
    {
        var options = new ChatOptions { Tools = tools };

        var response = await Spin("Thinking…", _ =>
            chatClient.GetResponseAsync(_history, options, ct));

        while (true)
        {
            var toolCalls = response.Messages
                .SelectMany(m => m.Contents.OfType<FunctionCallContent>())
                .ToList();

            if (toolCalls.Count == 0)
            {
                _history.AddMessages(response);
                return response.Text ?? string.Empty;
            }

            // Append assistant messages (with tool call requests) to history
            foreach (var msg in response.Messages)
                _history.Add(msg);

            // Execute each tool and append result to history
            foreach (var call in toolCalls)
            {
                var fn = tools.FirstOrDefault(t => t.Name == call.Name) as AIFunction;
                object? rawResult;

                if (fn is null)
                {
                    rawResult = $"Tool '{call.Name}' not found.";
                }
                else
                {
                    var fnArgs = call.Arguments is null ? null : new AIFunctionArguments(call.Arguments);
                    try { rawResult = await fn.InvokeAsync(fnArgs, ct); }
                    catch (Exception ex) { rawResult = $"Error: {ex.Message}"; }
                }

                _history.Add(new ChatMessage(ChatRole.Tool,
                    [new FunctionResultContent(call.CallId ?? string.Empty, rawResult)]));
            }

            response = await Spin("Thinking…", _ =>
                chatClient.GetResponseAsync(_history, options, ct));
        }
    }

    // ── Spinner ──────────────────────────────────────────────────────────────

    private static Task<T> Spin<T>(string status, Func<StatusContext, Task<T>> action) =>
        AnsiConsole.Status()
            .Spinner(Spectre.Console.Spinner.Known.Dots)
            .SpinnerStyle(Style.Parse("blue"))
            .StartAsync($"[blue]{status}[/]", action);

    // ── UI rendering ─────────────────────────────────────────────────────────

    private void RenderWelcome()
    {
        switch (style)
        {
            case UiStyle.Structured:
                AnsiConsole.Write(new Rule("[bold cyan]Oracle Assistant[/]").RuleStyle("cyan").LeftJustified());
                AnsiConsole.MarkupLine("[grey]Ask a database question. Type [bold]exit[/] to quit.[/]\n");
                break;
            case UiStyle.Minimal:
                AnsiConsole.MarkupLine("[teal]Oracle Assistant ready.[/] Ask a database question.");
                AnsiConsole.MarkupLine("[grey]Type [bold]exit[/] to quit.[/]\n");
                break;
            case UiStyle.Panels:
                AnsiConsole.Write(
                    new Panel("[bold]Oracle Assistant[/]\n[grey]Ask a database question.[/]")
                        .Header("[cyan]Ready[/]")
                        .BorderColor(Color.Cyan1)
                        .Padding(1, 0));
                AnsiConsole.MarkupLine("[grey]Type [bold]exit[/] to quit.[/]\n");
                break;
            default:
                throw new NotSupportedException($"Unknown UiStyle: {style}");
        }
    }

    private string RenderUserPrompt()
    {
        switch (style)
        {
            case UiStyle.Structured:
                AnsiConsole.Markup("[bold yellow]You ›[/] ");
                return Console.ReadLine() ?? string.Empty;
            case UiStyle.Minimal:
                AnsiConsole.Write(new Rule("[bold yellow]You[/]").RuleStyle("grey").LeftJustified());
                return Console.ReadLine() ?? string.Empty;
            case UiStyle.Panels:
                return AnsiConsole.Ask<string>("[bold yellow]You ›[/]");
            default:
                throw new NotSupportedException($"Unknown UiStyle: {style}");
        }
    }

    private void RenderResponse(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            AnsiConsole.MarkupLine("[grey](No response)[/]");
            return;
        }

        switch (style)
        {
            case UiStyle.Structured:
                AnsiConsole.MarkupLine("\n[bold green]Assistant ›[/]");
                Console.WriteLine(text);
                AnsiConsole.Write(new Rule().RuleStyle("grey"));
                AnsiConsole.WriteLine();
                break;
            case UiStyle.Minimal:
                AnsiConsole.Write(new Rule("[bold green]Assistant[/]").RuleStyle("grey").LeftJustified());
                Console.WriteLine(text);
                AnsiConsole.Write(new Rule().RuleStyle("grey"));
                AnsiConsole.WriteLine();
                break;
            case UiStyle.Panels:
                AnsiConsole.Write(new Rule("[bold green]Assistant[/]").RuleStyle("aquamarine3").LeftJustified());
                Console.WriteLine(text);
                AnsiConsole.Write(new Rule().RuleStyle("aquamarine3"));
                AnsiConsole.WriteLine();
                break;
            default:
                throw new NotSupportedException($"Unknown UiStyle: {style}");
        }
    }
}
```

- [ ] **Step 2: Build to verify `OracleAgent.cs` compiles**

```bash
cd src/OracleSqlclAgent
dotnet build
```

Expected: `Build succeeded.`

- [ ] **Step 3: Commit**

```bash
git add src/OracleSqlclAgent/OracleAgent.cs
git commit -m "feat: add OracleAgent with manual tool loop and Spectre.Console TUI"
```

---

## Task 4: Program.cs Bootstrap

**Files:**
- Modify: `src/OracleSqlclAgent/Program.cs` (replace placeholder from Task 1)

**Interfaces:**
- Consumes: `OracleAgent`, `AgentSkillsProvider`, five skill classes, `McpClient`, `IChatClient`
- Produces: runnable console entry point

- [ ] **Step 1: Write `Program.cs`**

Replace `src/OracleSqlclAgent/Program.cs` with:

```csharp
using Anthropic;
using Microsoft.AgentFramework.Skills;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Configuration;
using ModelContextProtocol.Client;
using OllamaSharp;
using OracleSqlclAgent;
using OracleSqlclAgent.Skills;
using Serilog;
using Spectre.Console;

// ── 1. Configuration ─────────────────────────────────────────────────────────

var configuration = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: false)
    .AddJsonFile(
        $"appsettings.{Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production"}.json",
        optional: true)
    .AddUserSecrets<Program>(optional: true)
    .AddEnvironmentVariables()
    .Build();

// ── 2. Serilog — error-only file logging ─────────────────────────────────────

Log.Logger = new LoggerConfiguration()
    .WriteTo.File(
        path: Path.Combine("logs", "error-.log"),
        rollingInterval: RollingInterval.Day,
        retainedFileCountLimit: 14,
        restrictedToMinimumLevel: Serilog.Events.LogEventLevel.Error,
        outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}")
    .CreateLogger();

try
{

// ── 3. Validate SQLcl path ────────────────────────────────────────────────────

var sqlclPath = configuration["SqlclMcp:Path"]
    ?? throw new InvalidOperationException(
        "Missing configuration: SqlclMcp:Path — update appsettings.json or appsettings.Development.json " +
        "with the full path to sql.exe from the Oracle SQL Developer VS Code extension.");

if (!File.Exists(sqlclPath))
    throw new InvalidOperationException(
        $"SQLcl binary not found at: {sqlclPath}\n" +
        "Update SqlclMcp:Path in appsettings.Development.json to the correct path.");

// ── 4. Start SQLcl MCP server ─────────────────────────────────────────────────

var transport = new StdioClientTransport(new StdioClientTransportOptions
{
    Command = sqlclPath,
    Arguments = ["-mcp"],
    Name = "sqlcl"
});

await using var mcpClient = await McpClient.CreateAsync(transport);

// ── 5. Enumerate MCP tools ────────────────────────────────────────────────────

var mcpTools = (await mcpClient.ListToolsAsync()).Cast<AITool>().ToList();

// ── 6. Register skills ────────────────────────────────────────────────────────

var skills = new AgentSkillsProvider();
skills.Register(new OracleSqlQuerySkill());
skills.Register(new OracleTableSchemaSkill());
skills.Register(new OracleTableConstraintsSkill());
skills.Register(new OracleTableRelationshipsSkill());
skills.Register(new OracleDatabaseInfoSkill());

const int skillCount = 5;

// ── 7. Build IChatClient ──────────────────────────────────────────────────────

var provider = configuration["AI:Provider"] ?? "Anthropic";
IChatClient chatClient = BuildChatClient(configuration, provider);
var modelDisplay = GetModelDisplay(configuration, provider);

// ── 8. Startup banner ─────────────────────────────────────────────────────────

const int W = 45;
string L(string s) => $"│  {s.PadRight(W)}│";
string T(string s) => $"│    - {s.PadRight(W - 4)}│";
Console.WriteLine($"┌{new string('─', W + 2)}┐");
Console.WriteLine(L("OracleSqlclAgent"));
Console.WriteLine(L($"Provider  : {provider}"));
Console.WriteLine(L($"Model     : {modelDisplay}"));
Console.WriteLine(L($"Tools ({mcpTools.Count})  :"));
foreach (var tool in mcpTools)
    Console.WriteLine(T(tool.Name ?? "(unnamed)"));
Console.WriteLine(L($"Skills ({skillCount}) : oracle-sql-query, oracle-table-schema,"));
Console.WriteLine(L($"           oracle-table-constraints, oracle-table-relationships,"));
Console.WriteLine(L($"           oracle-database-info"));
Console.WriteLine(L("Status    : READY"));
Console.WriteLine($"└{new string('─', W + 2)}┘");
Console.WriteLine();

// ── 9. UI style picker (2s timeout → Structured) ──────────────────────────────

var style = UiStyle.Structured;

AnsiConsole.MarkupLine("[bold]Select UI style:[/]");
AnsiConsole.MarkupLine("  [cyan][[1]][/] Structured - rules, spinners [grey](default)[/]");
AnsiConsole.MarkupLine("  [cyan][[2]][/] Minimal    - rule-separated turns");
AnsiConsole.MarkupLine("  [cyan][[3]][/] Panels     - bordered panel per message");
AnsiConsole.Markup("[grey]Choice [[1]]:[/] ");

try
{
    if (!Console.IsInputRedirected)
    {
        var deadline = DateTime.UtcNow.AddSeconds(2);
        while (DateTime.UtcNow < deadline && !Console.KeyAvailable)
            await Task.Delay(100);

        if (Console.KeyAvailable)
        {
            var key = Console.ReadKey(intercept: true);
            style = key.KeyChar switch
            {
                '2' => UiStyle.Minimal,
                '3' => UiStyle.Panels,
                _   => UiStyle.Structured
            };
        }
    }
}
catch (OperationCanceledException) { }

AnsiConsole.MarkupLine($"[green]{style}[/]\n");

// ── 10. Run agent ─────────────────────────────────────────────────────────────

await new OracleAgent(chatClient, mcpTools, skills, style).RunAsync();

}
catch (Exception ex)
{
    Log.Fatal(ex, "Unhandled exception in OracleSqlclAgent");
    AnsiConsole.MarkupLine($"[red]Fatal error:[/] {ex.Message}");
    AnsiConsole.MarkupLine("[grey]Details logged to logs/error-*.log[/]");
    Environment.ExitCode = 1;
}
finally
{
    await Log.CloseAndFlushAsync();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

static IChatClient BuildChatClient(IConfiguration config, string provider)
{
    if (string.Equals(provider, "Ollama", StringComparison.OrdinalIgnoreCase))
    {
        var endpoint = config["AI:Ollama:Endpoint"] ?? "http://localhost:11434";
        var model    = config["AI:Ollama:Model"]    ?? "llama3.2";
        var http     = new HttpClient { BaseAddress = new Uri(endpoint), Timeout = Timeout.InfiniteTimeSpan };
        return (IChatClient)new OllamaApiClient(http, model, null!);
    }

    // Default: Anthropic
    var apiKey = config["AI:Anthropic:ApiKey"];
    var claude = string.IsNullOrEmpty(apiKey)
        ? new AnthropicClient()                         // uses ANTHROPIC_API_KEY env var
        : new AnthropicClient() { ApiKey = apiKey };
    var claudeModel = config["AI:Anthropic:Model"] ?? "claude-opus-4-6";
    return claude.AsIChatClient(claudeModel);
}

static string GetModelDisplay(IConfiguration config, string provider) =>
    string.Equals(provider, "Ollama", StringComparison.OrdinalIgnoreCase)
        ? config["AI:Ollama:Model"] ?? "llama3.2"
        : config["AI:Anthropic:Model"] ?? "claude-opus-4-6";
```

- [ ] **Step 2: Build to verify no errors**

```bash
cd src/OracleSqlclAgent
dotnet build
```

Expected: `Build succeeded.`

Common issues:
- `AnthropicClient.AsIChatClient` not found → ensure `Microsoft.Extensions.AI.Anthropic` is installed; the extension method may be in a different namespace
- `McpClient.CreateAsync` signature mismatch → the `ModelContextProtocol` package API may have changed; check for `McpClientFactory.CreateAsync` as an alternative
- `OllamaApiClient` constructor signature → OllamaSharp versions differ; try `new OllamaApiClient(new Uri(endpoint), model)`

- [ ] **Step 3: Commit**

```bash
git add src/OracleSqlclAgent/Program.cs
git commit -m "feat: add OracleSqlclAgent Program.cs bootstrap"
```

---

## Task 5: Smoke Test

**Files:** none created

**Goal:** Verify the full stack — config → MCP → tools → agent — runs end to end against Docker Oracle XE.

- [ ] **Step 1: Update `appsettings.Development.json` with real values**

Open `src/OracleSqlclAgent/appsettings.Development.json` and set:
- `AI:Anthropic:ApiKey` to your `sk-ant-...` key
- `SqlclMcp:Path` to the full path to `sql.exe` (check memory file `sqlcl-location.md` for the exact path)

- [ ] **Step 2: Verify Docker Oracle XE is running**

```bash
docker compose ps
```

Expected: `oracle` container status `Up` and `healthy`.

If not running:
```bash
docker compose up -d
docker compose logs -f oracle
# Wait for: DATABASE IS READY TO USE!
```

- [ ] **Step 3: Run the agent**

```bash
cd src/OracleSqlclAgent
$env:DOTNET_ENVIRONMENT="Development"
dotnet run
```

Expected banner output (numbers may vary):
```
┌───────────────────────────────────────────────────┐
│  OracleSqlclAgent                                 │
│  Provider  : Anthropic                            │
│  Model     : claude-opus-4-6                      │
│  Tools (7)  :                                     │
│    - connections_list                             │
│    - connect                                      │
│    - disconnect                                   │
│    - sql_run                                      │
│    - sqlcl_run                                    │
│    - schema_information                           │
│    - request_status                               │
│  Skills (5) : oracle-sql-query, oracle-table-...  │
│  Status    : READY                                │
└───────────────────────────────────────────────────┘
```

- [ ] **Step 4: Run a smoke query**

At the `You ›` prompt, type:

```
how many employees are in the database?
```

Expected: agent connects to `hr_local`, runs a COUNT query, returns `The HR schema has 5 employees.`

- [ ] **Step 5: Verify skill routing**

Type:

```
show me the schema of the employees table
```

Expected: agent uses `oracle-table-schema` skill, queries `user_tab_columns`, returns column list with types.

- [ ] **Step 6: Type `exit` to quit cleanly**

```
exit
```

Expected: clean exit, no error output, no `logs/error-*.log` created.

- [ ] **Step 7: Final commit**

```bash
git add src/OracleSqlclAgent/
git commit -m "feat: complete OracleSqlclAgent — MAF skills + SQLcl MCP console agent"
```

---

## Package Troubleshooting Reference

| Symptom | Likely cause | Fix |
|---|---|---|
| `Microsoft.AgentFramework.Skills` not found | Package name changed | Search NuGet: `dotnet package search AgentFramework` |
| `AgentClassSkill` not found | Namespace change | Add local base class fallback (see Task 2 Step 6) |
| `McpClient.CreateAsync` not found | API version change | Try `McpClientFactory.CreateAsync(transport)` |
| `AnthropicClient.AsIChatClient` not found | Extension not in scope | Add `using Microsoft.Extensions.AI;` |
| `OllamaApiClient` constructor error | OllamaSharp version | Try `new OllamaApiClient(new Uri(endpoint), model)` |
| Banner shows 0 tools | SQLcl not starting | Check `SqlclMcp:Path` value; run `sql.exe -mcp` manually to test |

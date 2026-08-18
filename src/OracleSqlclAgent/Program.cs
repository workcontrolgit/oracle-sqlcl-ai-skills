using Anthropic;
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

McpClient? oracleClient = null;
try
{

// ── 3. Resolve SQLcl path and connection name ─────────────────────────────────

var sqlclPath      = configuration["SqlclMcp:Path"];
var connectionName = configuration["SqlclMcp:ConnectionName"] ?? "hr_local";

// ── 4. Start SQLcl MCP server (optional) ─────────────────────────────────────

List<AITool> mcpTools = [];

if (!string.IsNullOrWhiteSpace(sqlclPath) && File.Exists(sqlclPath))
{
    var transport = new StdioClientTransport(new StdioClientTransportOptions
    {
        Command = sqlclPath,
        Arguments = ["-mcp"],
        Name = "OracleSqlcl",
        StandardErrorLines = line => Log.Debug("[SQLcl MCP] {Line}", line)
    });
    oracleClient = await McpClient.CreateAsync(transport);

    // ── 5. Enumerate MCP tools ────────────────────────────────────────────────
    mcpTools = (await oracleClient.ListToolsAsync()).Cast<AITool>().ToList();
}
else
{
    AnsiConsole.MarkupLine("[yellow]Warning:[/] SQLcl not found — Oracle MCP tools disabled.");
    AnsiConsole.MarkupLine("[grey]Set SqlclMcp:Path in appsettings.json to enable Oracle connectivity.[/]");
    AnsiConsole.WriteLine();
}

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
var defaultChatOptions = BuildDefaultChatOptions(configuration, provider);

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
Console.WriteLine(L($"Skills ({skillCount}) :"));
Console.WriteLine(T("oracle-sql-query"));
Console.WriteLine(T("oracle-table-schema"));
Console.WriteLine(T("oracle-table-constraints"));
Console.WriteLine(T("oracle-table-relationships"));
Console.WriteLine(T("oracle-database-info"));
Console.WriteLine(L("Status    : READY"));
Console.WriteLine($"└{new string('─', W + 2)}┘");
Console.WriteLine();

// ── 9. UI style ───────────────────────────────────────────────────────────────

var style = UiStyle.Structured;

// ── 10. Run agent ─────────────────────────────────────────────────────────────

await new OracleAgent(chatClient, mcpTools, skills, style, defaultChatOptions, connectionName).RunAsync();

}
catch (Exception ex)
{
    Log.Fatal(ex, "Unhandled exception in OracleSqlclAgent");
    AnsiConsole.MarkupLine($"[red]Fatal error:[/] {ex.Message.EscapeMarkup()}");
    AnsiConsole.MarkupLine("[grey]Details logged to logs/error-*.log[/]");
    Environment.ExitCode = 1;
}
finally
{
    if (oracleClient is not null)
        await oracleClient.DisposeAsync();
    await Log.CloseAndFlushAsync();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

static ChatOptions BuildDefaultChatOptions(IConfiguration config, string provider)
{
    var options = new ChatOptions();
    if (string.Equals(provider, "Ollama", StringComparison.OrdinalIgnoreCase))
    {
        var numCtxStr = config["AI:Ollama:NumCtx"];
        if (int.TryParse(numCtxStr, out var numCtx) && numCtx > 0)
        {
            options.AdditionalProperties = new AdditionalPropertiesDictionary
            {
                ["num_ctx"] = numCtx
            };
        }
    }
    return options;
}

static IChatClient BuildChatClient(IConfiguration config, string provider)
{
    if (string.Equals(provider, "Ollama", StringComparison.OrdinalIgnoreCase))
    {
        var endpoint = config["AI:Ollama:Endpoint"] ?? "http://localhost:11434";
        var model    = config["AI:Ollama:Model"]    ?? "llama3.2";
        var http     = new HttpClient { BaseAddress = new Uri(endpoint), Timeout = Timeout.InfiniteTimeSpan };
        return (IChatClient)new OllamaApiClient(http, model, null!);
    }

    if (string.Equals(provider, "AzureOpenAI", StringComparison.OrdinalIgnoreCase))
    {
        var endpoint   = config["AI:AzureOpenAI:Endpoint"]       ?? throw new InvalidOperationException("Missing AI:AzureOpenAI:Endpoint");
        var deployment = config["AI:AzureOpenAI:DeploymentName"] ?? throw new InvalidOperationException("Missing AI:AzureOpenAI:DeploymentName");
        var apiKey     = config["AI:AzureOpenAI:ApiKey"]         ?? throw new InvalidOperationException("Missing AI:AzureOpenAI:ApiKey — run: dotnet user-secrets set \"AI:AzureOpenAI:ApiKey\" \"YOUR_KEY\"");
        var azureClient = new Azure.AI.OpenAI.AzureOpenAIClient(new Uri(endpoint), new System.ClientModel.ApiKeyCredential(apiKey));
        return azureClient.GetChatClient(deployment).AsIChatClient();
    }

    // Default: Anthropic
    var anthropicKey = config["AI:Anthropic:ApiKey"];
    var claude = string.IsNullOrEmpty(anthropicKey)
        ? new AnthropicClient()
        : new AnthropicClient() { ApiKey = anthropicKey };
    var claudeModel = config["AI:Anthropic:Model"] ?? "claude-opus-4-6";
    return claude.AsIChatClient(claudeModel);
}

static string GetModelDisplay(IConfiguration config, string provider) =>
    provider.ToLowerInvariant() switch
    {
        "ollama"      => config["AI:Ollama:Model"]                ?? "llama3.2",
        "azureopenai" => config["AI:AzureOpenAI:DeploymentName"] ?? "gpt-4o-mini",
        _             => config["AI:Anthropic:Model"]             ?? "claude-opus-4-6"
    };

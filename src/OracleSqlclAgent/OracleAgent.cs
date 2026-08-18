using Microsoft.Extensions.AI;
using Spectre.Console;

namespace OracleSqlclAgent;

public enum UiStyle { Structured, Minimal, Panels }

public sealed class OracleAgent
{
    private readonly IChatClient _chatClient;
    private readonly IList<AITool> _tools;
    private readonly UiStyle _style;
    private readonly ChatOptions _agentOptions;
    private readonly List<ChatMessage> _history;
    private readonly string _connectionName;

    private const int MaxIterations = 20;

    public OracleAgent(
        IChatClient chatClient,
        IList<AITool> tools,
        AgentSkillsProvider skills,
        UiStyle style = UiStyle.Structured,
        ChatOptions? defaultOptions = null,
        string connectionName = "hr_local")
    {
        _chatClient = chatClient;
        _tools = tools;
        _style = style;
        _connectionName = connectionName;
        _history = [];
        _agentOptions = new ChatOptions
        {
            Tools = [.. tools],
            AdditionalProperties = defaultOptions?.AdditionalProperties
        };
    }

    // ── Pre-connect ──────────────────────────────────────────────────────────

    private async Task ConnectAsync(CancellationToken ct)
    {
        var fn = _tools.OfType<AIFunction>()
            .FirstOrDefault(t => string.Equals(t.Name, "connect", StringComparison.OrdinalIgnoreCase));
        if (fn is null) return;
        try
        {
            await fn.InvokeAsync(
                new AIFunctionArguments(new Dictionary<string, object?> { ["connection_name"] = _connectionName }),
                ct);
        }
        catch { /* will reconnect on first tool call if needed */ }
    }

    // ── REPL ─────────────────────────────────────────────────────────────────

    public async Task RunAsync(CancellationToken ct = default)
    {
        await ConnectAsync(ct);
        RenderWelcome();

        while (!ct.IsCancellationRequested)
        {
            var input = RenderUserPrompt();
            if (string.IsNullOrWhiteSpace(input)) continue;
            if (input.Equals("exit", StringComparison.OrdinalIgnoreCase)) break;

            var text = await Spin("Thinking\u2026", _ => RunAgentLoopAsync(input, ct));
            RenderResponse(text);
        }
    }

    public async Task<string> AskAsync(string input, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(input)) return string.Empty;
        return await RunAgentLoopAsync(input, ct);
    }

    // ── Agentic loop ─────────────────────────────────────────────────────────

    private string SystemPrompt => $"""
        You are an Oracle database assistant with access to SQLcl MCP tools.
        Default connection: {_connectionName}
        Schema: Oracle HR sample schema (EMPLOYEES, DEPARTMENTS, JOBS, LOCATIONS, COUNTRIES, REGIONS, JOB_HISTORY).

        To answer database questions, use the tools in this order:
        1. 'connect' — with connection_name='{_connectionName}'
        2. 'sql_run' — SQL queries, parameter name is 'sql' (e.g. sql: "SELECT * FROM employees")
        3. 'schema_information' — schema/metadata exploration (no SQL needed)
        4. 'disconnect' — when done

        Present results clearly with markdown tables and a one-sentence summary.
        For non-database questions, answer directly without calling any tools.
        """;

    private async Task<string> RunAgentLoopAsync(string userInput, CancellationToken ct)
    {
        var messages = new List<ChatMessage> { new(ChatRole.System, SystemPrompt) };
        messages.AddRange(_history);
        messages.Add(new ChatMessage(ChatRole.User, userInput));

        for (int i = 0; i < MaxIterations; i++)
        {
            var response = await _chatClient.GetResponseAsync(messages, _agentOptions, ct);

            foreach (var msg in response.Messages)
                messages.Add(msg);

            var calls = response.Messages
                .SelectMany(m => m.Contents)
                .OfType<FunctionCallContent>()
                .ToList();

            if (calls.Count == 0)
            {
                _history.Add(new ChatMessage(ChatRole.User, userInput));
                _history.Add(new ChatMessage(ChatRole.Assistant, response.Text ?? string.Empty));
                return response.Text ?? string.Empty;
            }

            foreach (var call in calls)
            {
                var result = await InvokeToolAsync(call, ct);
                messages.Add(new ChatMessage(ChatRole.Tool,
                    [new FunctionResultContent(call.CallId, result)]));
            }
        }

        return "[Agent loop reached the iteration limit — please rephrase your question]";
    }

    private async Task<object?> InvokeToolAsync(FunctionCallContent call, CancellationToken ct)
    {
        var fn = _tools.OfType<AIFunction>()
            .FirstOrDefault(t => string.Equals(t.Name, call.Name, StringComparison.OrdinalIgnoreCase));

        if (fn is null) return $"[Tool '{call.Name}' not found]";

        try
        {
            return await fn.InvokeAsync(
                new AIFunctionArguments(call.Arguments ?? new Dictionary<string, object?>()),
                ct);
        }
        catch (Exception ex)
        {
            return $"[Tool error: {ex.Message}]";
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
        switch (_style)
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
                throw new NotSupportedException($"Unknown UiStyle: {_style}");
        }
    }

    private string RenderUserPrompt()
    {
        switch (_style)
        {
            case UiStyle.Structured:
                AnsiConsole.Markup("[bold yellow]You \u203a[/] ");
                return Console.ReadLine() ?? string.Empty;
            case UiStyle.Minimal:
                AnsiConsole.Write(new Rule("[bold yellow]You[/]").RuleStyle("grey").LeftJustified());
                return Console.ReadLine() ?? string.Empty;
            case UiStyle.Panels:
                return AnsiConsole.Ask<string>("[bold yellow]You \u203a[/]");
            default:
                throw new NotSupportedException($"Unknown UiStyle: {_style}");
        }
    }

    private void RenderResponse(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            AnsiConsole.MarkupLine("[grey](No response)[/]");
            return;
        }

        switch (_style)
        {
            case UiStyle.Structured:
                AnsiConsole.MarkupLine("\n[bold green]Assistant \u203a[/]");
                MarkdigSpectreRenderer.Render(text);
                AnsiConsole.Write(new Rule().RuleStyle("grey"));
                AnsiConsole.WriteLine();
                break;
            case UiStyle.Minimal:
                AnsiConsole.Write(new Rule("[bold green]Assistant[/]").RuleStyle("grey").LeftJustified());
                MarkdigSpectreRenderer.Render(text);
                AnsiConsole.Write(new Rule().RuleStyle("grey"));
                AnsiConsole.WriteLine();
                break;
            case UiStyle.Panels:
                AnsiConsole.Write(new Rule("[bold green]Assistant[/]").RuleStyle("aquamarine3").LeftJustified());
                MarkdigSpectreRenderer.Render(text);
                AnsiConsole.Write(new Rule().RuleStyle("aquamarine3"));
                AnsiConsole.WriteLine();
                break;
            default:
                throw new NotSupportedException($"Unknown UiStyle: {_style}");
        }
    }
}

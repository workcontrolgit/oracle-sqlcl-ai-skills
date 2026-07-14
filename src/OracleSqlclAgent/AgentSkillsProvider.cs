namespace OracleSqlclAgent;

public sealed class AgentSkillsProvider
{
    private readonly List<AgentClassSkill> _skills = new();

    public void Register(AgentClassSkill skill) => _skills.Add(skill);

    public IReadOnlyList<AgentClassSkill> Skills => _skills;

    public string BuildSkillsContext() =>
        string.Join("\n", _skills.Select(s => $"- {s.Name}: {s.Description}"));
}

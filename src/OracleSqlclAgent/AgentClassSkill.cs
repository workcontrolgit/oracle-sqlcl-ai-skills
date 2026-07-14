namespace OracleSqlclAgent;

public abstract class AgentClassSkill
{
    public abstract string Name { get; }
    public abstract string Description { get; }
    protected abstract string Instructions { get; }
    public string GetInstructions() => Instructions;
}

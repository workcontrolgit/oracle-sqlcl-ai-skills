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

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

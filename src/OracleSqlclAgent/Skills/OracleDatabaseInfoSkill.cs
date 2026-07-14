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

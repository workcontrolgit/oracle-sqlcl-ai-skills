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

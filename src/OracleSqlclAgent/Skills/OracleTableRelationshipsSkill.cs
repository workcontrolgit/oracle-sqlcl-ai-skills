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

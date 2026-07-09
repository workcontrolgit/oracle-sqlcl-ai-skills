# oracle-user-permissions Skill

Check user/role privileges and identify permission gaps against Oracle HR schema requirements.

## Purpose

This skill queries Oracle database privilege views to:
- Identify all system-level privileges granted to a user
- Identify all object-level privileges on HR schema tables  
- List assigned roles
- Query active session privileges
- Compare against baseline requirements for HR schema access
- Generate recommendations for missing grants

## Parameters

### -Environment (Mandatory)
Target environment: `local`, `staging`, or `production`

Values: `local` | `staging` | `production`

### -Username (Optional)
Oracle username to check. Default: Current Oracle user from environment configuration (typically `HR`)

Default: *environment default user*

### -CheckSystemPrivileges (Optional)
Include system privilege analysis in results. Adds DBA_SYS_PRIVS query.

Type: `[switch]`  
Default: `$false`

## Output Format

### JSON Report
```json
{
  "Title": "User Permissions Report",
  "Status": "PASS" or "PERMISSIONS_GAP_DETECTED",
  "Environment": "local",
  "Username": "HR",
  "SystemPrivilegesCount": 2,
  "ObjectPrivilegesCount": 18,
  "RolesAssigned": 2,
  "SessionPrivilegesCount": 25,
  "PermissionGaps": 3,
  "Details": {
    "SystemPrivileges": ["CREATE SESSION", "ALTER SESSION"],
    "ObjectPrivileges": ["SELECT on EMPLOYEES", "INSERT on DEPARTMENTS"],
    "Roles": ["RESOURCE", "CONNECT"],
    "MissingGrants": ["GRANT SELECT ON EMPLOYEES TO HR"]
  }
}
```

### Markdown Report
Displays a permission summary table with privilege counts and recommendations for missing grants.

## Exit Codes

- `0`: Success (complete scan)
- `1`: Error (query failure, invalid parameters, or environment issue)

## Examples

### Basic Usage - Check Current User Privileges
```powershell
& oracle-user-permissions.ps1 -Environment local
```

### Check Specific User
```powershell
& oracle-user-permissions.ps1 -Environment local -Username APPUSER
```

### Include System Privileges  
```powershell
& oracle-user-permissions.ps1 -Environment local -CheckSystemPrivileges
```

### Production Environment
```powershell
& oracle-user-permissions.ps1 -Environment production -Username PROD_APP_USER
```

## Privilege Requirements Baseline

### HR Schema Tables
The skill checks for these standard HR schema privileges:

| Table | Required Privileges |
|---|---|
| EMPLOYEES | SELECT, INSERT, UPDATE, DELETE |
| DEPARTMENTS | SELECT, INSERT, UPDATE, DELETE |
| JOBS | SELECT, INSERT, UPDATE, DELETE |
| LOCATIONS | SELECT, INSERT, UPDATE |
| COUNTRIES | SELECT |
| REGIONS | SELECT |

### System Privileges (when -CheckSystemPrivileges)
- CREATE SESSION
- ALTER SESSION

## Permission Gaps and Recommendations

When `Status` is `PERMISSIONS_GAP_DETECTED`, the `MissingGrants` array contains SQL GRANT statements formatted as:
```sql
GRANT <privilege> ON <table> TO {USERNAME}
```

Example:
```sql
GRANT SELECT ON EMPLOYEES TO HR
GRANT INSERT ON DEPARTMENTS TO HR
```

Replace `{USERNAME}` with the actual target user when executing.

## Common Permission Gaps

### Typical for Read-Only Users
- Missing INSERT, UPDATE, DELETE on transactional tables
- Missing privileges on LOCATIONS, COUNTRIES, REGIONS (often read-only)

### Typical for Application Service Accounts
- Missing privileges on all HR tables
- Missing required system privileges
- Roles not yet assigned

## Security Considerations

- **No Credentials Stored:** Script uses environment configuration for connection details
- **Query Restriction:** Only SELECT queries allowed via whitelist validation
- **SQL Injection Prevention:** All table names validated against Oracle naming conventions (1-30 alphanumeric chars + underscore)
- **Escaped Input:** User-provided usernames escaped before SQL execution

## Dependencies

- PowerShell 5.1+
- OracleConnection.psm1 (multi-environment configuration)
- OutputFormatter.psm1 (JSON + markdown output)
- SchemaInspector.psm1 (schema metadata queries)
- Environments.json (connection configuration)

## Notes

- Requires Oracle DBA_ views readable by current user
- Session privileges reflect all privileges active in the current session (including inherited from roles)
- Missing grants recommendations assume user should have full HR schema access
- For application-specific privilege models, customize `$requiredTablePrivileges` hashtable in script


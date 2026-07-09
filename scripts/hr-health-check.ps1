$sql = @'
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 200
SET LINESIZE 200
COLUMN table_name FORMAT A35
PROMPT ==== HR USER ====
SELECT username, account_status FROM dba_users WHERE username = 'HR';
PROMPT ==== HR TABLES ====
SELECT table_name FROM all_tables WHERE owner = 'HR' ORDER BY table_name;
EXIT;
'@

$sql | docker exec -i oracle-hr sqlplus -s system/OracleSys_2026@//localhost:1521/XEPDB1

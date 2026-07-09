#!/bin/bash
set -euo pipefail

needs_bootstrap=$(sqlplus -s / as sysdba <<'SQL'
SET HEADING OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET PAGESIZE 0

ALTER SESSION SET CONTAINER = XEPDB1;

SELECT CASE
         WHEN (SELECT COUNT(*) FROM dba_users WHERE username = 'HR') = 1
          AND (SELECT COUNT(*) FROM all_tables WHERE owner = 'HR') >= 7
           THEN 'NO'
         ELSE 'YES'
       END
FROM dual;

EXIT;
SQL
)

needs_bootstrap="$(echo "${needs_bootstrap}" | tr -d '[:space:]')"

if [ "${needs_bootstrap}" = "YES" ]; then
  echo "HR schema missing or incomplete. Bootstrapping HR schema..."

  sqlplus -s / as sysdba <<'SQL'
ALTER SESSION SET CONTAINER = XEPDB1;
@/container-entrypoint-initdb.d/01-create-hr-user.sql
CONNECT hr/HrUser_2026@//localhost:1521/XEPDB1
@/container-entrypoint-initdb.d/02-hr-schema.sql
EXIT;
SQL
else
  echo "HR schema already present. Skipping bootstrap."
fi
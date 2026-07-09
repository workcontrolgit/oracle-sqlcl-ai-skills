# Docker Oracle HR Schema

This workspace provides a local Oracle XE database in Docker with an initialized HR schema and sample data.

## Prerequisites

- Docker Desktop (Windows) with Linux containers enabled
- Docker Compose v2

## Quick Start

1. Start Oracle XE and run schema initialization:

   ```powershell
   docker compose up -d
   ```

2. Follow container logs until database is ready:

   ```powershell
   docker compose logs -f oracle
   ```

3. Connect as HR user:

   - Host: `localhost`
   - Port: `1521`
   - Service: `XEPDB1`
   - Username: `hr`
   - Password: `HrUser_2026`

## Credentials

Default users and passwords in this workspace:

- `SYSTEM` user password: `OracleSys_2026`
- `HR` user password: `HrUser_2026`

How these passwords are set:

- `SYSTEM` (`SYS`/`SYSTEM`) password comes from `ORACLE_PASSWORD` in `docker-compose.yml`.
- `HR` password is set in `init-scripts/01-create-hr-user.sql` (`CREATE USER hr IDENTIFIED BY HrUser_2026`).
- `start-scripts/00-ensure-hr.sh` checks HR schema at container startup and runs the bootstrap SQL when HR is missing/incomplete, which also sets `HR` password from `01-create-hr-user.sql`.

Important behavior:

- `ORACLE_PASSWORD` is applied on first database initialization. If the volume already exists, Oracle ignores this env var on startup.
- To apply changed init/start scripts from scratch, run a full reset:

```powershell
docker compose down -v
docker compose up -d
```

How to change passwords without deleting data:

- Change `SYSTEM` password in running container:

```powershell
docker exec -it oracle-hr resetPassword <new-system-password>
```

- Change `HR` password in running DB:

```powershell
@"
ALTER USER hr IDENTIFIED BY <new-hr-password>;
EXIT;
"@ | docker exec -i oracle-hr sqlplus -s system/OracleSys_2026@//localhost:1521/XEPDB1
```

## Useful Commands

Start services:

```powershell
docker compose up -d
```

Stop services:

```powershell
docker compose down
```

Reset database (delete all persisted data and re-run init scripts):

```powershell
docker compose down -v
docker compose up -d
```

Run an SQL query from inside the container:

```powershell
docker exec -it oracle-hr sqlplus hr/HrUser_2026@//localhost:1521/XEPDB1
```

## Project Structure

- `docker-compose.yml`: Oracle XE container configuration.
- `init-scripts/`: SQL scripts used for HR bootstrap.
- `start-scripts/`: Startup scripts executed on every container start to ensure HR schema exists.
- `docs/schema-overview.md`: HR schema entities and relationships.
- `.vscode/tasks.json`: VS Code tasks for common Docker operations.

## Notes

- Startup scripts verify `HR` schema exists on each start and bootstrap it if missing.
- To apply script changes, use a full reset (`docker compose down -v`).

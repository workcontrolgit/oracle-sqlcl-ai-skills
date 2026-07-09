# anatomy.md

> Auto-maintained by OpenWolf. Last scanned: 2026-07-09T17:59:01.103Z
> Files: 20 tracked | Anatomy hits: 0 | Misses: 0

## ./

- `CLAUDE.md` — OpenWolf (~57 tok)
- `docker-compose.yml` — Docker Compose services (~188 tok)
- `README.md` — Project documentation (~720 tok)

## .claude/

- `mcp.json` (~178 tok)
- `settings.json` (~452 tok)

## .claude/rules/

- `openwolf.md` (~313 tok)

## .claude/skills/oracle-skills/

- `README.md` — Project documentation (~475 tok)

## .claude/skills/oracle-skills/config/

- `credentials-example.json` (~91 tok)
- `environments.json` (~336 tok)

## .claude/skills/oracle-skills/shared/

- `OracleConnection.psm1` — Multi-env Oracle connection: config expansion, query execution (SQL injection validation, timeout, CSV/JSON parsing), connectivity test, version query (~2052 tok)

## .claude/skills/oracle-skills/tests/

- `OracleConnection.Tests.ps1` — Pester 27-test suite: env config (expansion, fail-fast), query (SQL injection, timeout, output format), connection (boolean result), version; security & error handling validation (~2279 tok)

## .github/

- `copilot-instructions.md` (~352 tok)

## .github/prompts/

- `oracle-query-helper.prompt.md` (~434 tok)

## docs/

- `schema-overview.md` — HR Schema Overview (~215 tok)

## docs/superpowers/plans/

- `2026-07-09-oracle-skills-implementation.md` — Oracle Skills Taxonomy Implementation Plan (PowerShell) (~7595 tok)

## docs/superpowers/specs/

- `2026-07-09-oracle-skills-taxonomy-design.md` — Oracle Skills Taxonomy Design (~2480 tok)

## init-scripts/

- `01-create-hr-user.sql` — SQL: 1 view(s) (~129 tok)
- `02-hr-schema.sql` — SQL: tables: regions, countries, locations, departments (~1941 tok)

## scripts/

- `hr-health-check.ps1` (~111 tok)

## start-scripts/

- `00-ensure-hr.sh` (~255 tok)

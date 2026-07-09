# anatomy.md

> Auto-maintained by OpenWolf. Last scanned: 2026-07-09T21:14:37.066Z
> Files: 44 tracked | Anatomy hits: 0 | Misses: 0

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

- `OracleConnection.psm1` — Get: environment, environment, environment (~2054 tok)
- `OutputFormatter.psm1` — Declares ConvertTo (~2053 tok)
- `SchemaInspector.psm1` — Declares Get (~1677 tok)

## .claude/skills/oracle-skills/tests/

- `OracleConnection.Tests.ps1` — Declares should (~2304 tok)
- `OutputFormatter.Tests.ps1` (~3366 tok)
- `SchemaInspector.Tests.ps1` (~2621 tok)
- `Tier2.Migration.Tests.ps1` — Pester tests for oracle-migration-status skill (~310 tok)
- `Tier2.MigrationDiff.Tests.ps1` — Pester tests for oracle-migration-diff skill (~170 tok)
- `Tier2.SchemaConflict.Tests.ps1` (~2086 tok)
- `Tier2.SchemaReset.Tests.ps1` — Pester tests for oracle-schema-reset skill (~270 tok)
- `Tier2.UserPermissions.Tests.ps1` — Pester tests for oracle-user-permissions skill (~350 tok)

## .claude/skills/oracle-skills/tier2/

- `oracle-migration-diff.md` — Skill documentation: schema diff comparison logic (~380 tok)
- `oracle-migration-diff.ps1` — Declares Get (~2091 tok)
- `oracle-migration-status.md` — Skill documentation: purpose, parameters, output format (~390 tok)
- `oracle-migration-status.ps1` — Query and display Oracle schema migration status (~310 tok)
- `oracle-schema-conflict-detect.md` — oracle-schema-conflict-detect (~1290 tok)
- `oracle-schema-conflict-detect.ps1` — Declares Get (~3956 tok)
- `oracle-schema-reset.md` — oracle-schema-reset Skill (~1595 tok)
- `oracle-schema-reset.ps1` — Declares Test (~2340 tok)
- `oracle-user-permissions.md` — oracle-user-permissions Skill documentation (~1250 tok)
- `oracle-user-permissions.ps1` — Check user privileges and identify permission gaps (~2650 tok)

## .claude/skills/oracle-skills/tier3/

- `oracle-schema-compare-environments.md` — oracle-schema-compare-environments (~1473 tok)
- `oracle-schema-compare-environments.ps1` — Get: foreach, foreach (~3570 tok)
- `oracle-schema-compare-environments.Tests.ps1` — in: environments (~2750 tok)

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
- `oracle-schema-reset.md` — Skill documentation: security, parameters, usage (~400 tok)
- `oracle-schema-reset.ps1` — Safely reset schema to known state (dev only), drop tables (~310 tok)

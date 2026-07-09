# Oracle Skills Taxonomy Design

**Date:** 2026-07-09  
**Status:** Approved  
**Scope:** Expand Oracle database skills to support dev workflows and CI/CD automation

## Executive Summary

This design organizes Oracle database skills into three hierarchical tiers based on function and audience:

1. **Exploration** (9 existing skills) — Schema introspection and discovery
2. **Dev Support** (5 new skills) — Developer debugging and troubleshooting
3. **CI/CD Automation** (5 new skills) — Environment validation and consistency checks

The hierarchy enables developers to troubleshoot locally while supporting automated pipeline validation across dev/staging/prod environments.

## Problem Statement

### Current State
- 9 Oracle skills exist for exploration (searching tables, examining constraints, running queries)
- No standardized way to troubleshoot failed migrations or schema conflicts
- No pipeline support for validating schema consistency across environments (local/staging/prod)
- Developers lack tools for diagnosing schema drift or permission issues

### Requirements
- **Dev workflow:** Troubleshoot failed migrations and schema conflicts
- **CI/CD workflow:** Validate schema consistency across dev + staging + production
- **Audience:** Both developers (ad-hoc debugging) and pipelines (automated checks)
- **Environments:** Local (Oracle XE), staging (full Oracle), production (full Oracle)

## Design: Three-Tier Hierarchy

### Tier 1: Exploration (Existing)

**Purpose:** Understand the schema, locate objects, inspect relationships.

**Skills (9 existing):**
- `oracle-database-info` — Database version, schema info
- `oracle-hr-query` — Query HR database schema/data
- `oracle-search-columns` — Find columns by name/pattern
- `oracle-search-tables` — Find tables by name/pattern
- `oracle-sql-query` — Execute arbitrary SQL
- `oracle-table-schema` — Inspect table structure, columns, data types
- `oracle-table-constraints` — Examine PK/FK/unique constraints
- `oracle-table-indexes` — Examine indexes, performance metadata
- `oracle-table-relationships` — Explore foreign key relationships

**Audience:** Developers, automation scripts  
**Output Style:** Data-first (raw results, minimal interpretation)  
**Integration:** Foundation layer for other tiers to call

---

### Tier 2: Dev Support (New)

**Purpose:** Help developers troubleshoot migrations and schema issues during development.

**Audience:** Developers (local or shared dev environment)  
**Output Style:** Diagnostic + actionable (problem + suggested fix)

**Skills (5 new):**

#### 1. `oracle-migration-status`
- **Purpose:** Show pending/applied migrations, last applied date, any failures
- **Use case:** "Where are we in the migration chain? Did the last migration succeed?"
- **Inputs:** Environment (local/staging/prod), optional migrations table reference
- **Outputs:** Migration log, current version, pending migrations, any failures
- **Example:** Returns chronological list of migrations with apply timestamps and success/failure status

#### 2. `oracle-migration-diff`
- **Purpose:** Compare current schema against expected migration target
- **Use case:** "What did the migration miss?"
- **Inputs:** Environment, migration version to compare against
- **Outputs:** Missing/extra tables, columns, constraints; recommendations
- **Example:** "Migration expected 5 columns in EMPLOYEES, found 4 (missing HIRE_DATE)"

#### 3. `oracle-schema-conflict-detect`
- **Purpose:** Identify manual schema changes vs. migration-tracked changes
- **Use case:** "What changed that wasn't in migrations?"
- **Inputs:** Environment, reference migration version
- **Outputs:** Drift report (manual changes, orphaned objects, unexpected modifications)
- **Example:** "DEPARTMENTS table has new column COST_CENTER not in any migration"

#### 4. `oracle-schema-reset`
- **Purpose:** Safely reset schema to known state (dev only), re-apply init scripts, seed data
- **Use case:** "Start fresh without losing the container"
- **Inputs:** Environment (dev only), target version (optional)
- **Outputs:** Reset confirmation, final schema state
- **Security:** Works only on local/dev, not staging/prod

#### 5. `oracle-user-permissions`
- **Purpose:** Check user/role privileges, identify what's missing
- **Use case:** "Why can't this user access this table?"
- **Inputs:** User/role name, environment
- **Outputs:** Granted privileges, missing privileges, recommendations
- **Example:** "HR user missing SELECT on EMPLOYEES; recommend: GRANT SELECT ON EMPLOYEES TO hr"

---

### Tier 3: CI/CD Automation (New)

**Purpose:** Validate schema consistency across environments; automate pre-deployment checks.

**Audience:** CI/CD pipelines, release engineers, automation scripts  
**Output Style:** Machine-readable (JSON/structured) + human summary for logs  
**Environment Support:** Works across local (XE) + staging + production

**Skills (5 new):**

#### 1. `oracle-schema-compare-environments`
- **Purpose:** Compare schema between two environments (dev vs. staging, staging vs. prod)
- **Use case:** Pre-deploy validation: "Are staging and prod at the same schema version?"
- **Inputs:** Source environment, target environment
- **Outputs:** Pass/fail, detailed diff (missing tables, column type mismatches, constraint gaps)
- **Format:** JSON for pipeline parsing, markdown summary for humans
- **Example:** Returns structured diff showing 2 missing tables, 3 column type mismatches, 0 constraint gaps → FAIL

#### 2. `oracle-migration-validate`
- **Purpose:** Verify all expected migrations are applied in target environment
- **Use case:** "Before deployment, is this environment migration-ready?"
- **Inputs:** Environment, expected migration list (from code)
- **Outputs:** Pass/fail, which migrations are missing/pending
- **Format:** JSON exit codes, human-readable checklist
- **Example:** Compares expected migrations against applied migrations table

#### 3. `oracle-pre-deploy-check`
- **Purpose:** Run all pre-deployment validations in one call
- **Use case:** Single gate for deployment pipelines
- **Inputs:** Target environment (staging/prod), expected schema version
- **Validations:**
  - Schema consistency (vs. previous environment or baseline)
  - Migration status (all expected migrations applied)
  - User permissions (required users exist with proper roles)
  - Connectivity (can connect to database)
- **Outputs:** Pass/fail for each check, aggregate status
- **Format:** JSON with pass/fail per check, exit code

#### 4. `oracle-schema-drift-detect`
- **Purpose:** Identify manual schema changes (drift) outside migrations
- **Use case:** Pre-deploy: "This environment has out-of-sync changes we need to track"
- **Inputs:** Environment, reference migration baseline
- **Outputs:** List of objects not in migrations, unexpected changes
- **Format:** JSON report + human summary

#### 5. `oracle-environment-sync-status`
- **Purpose:** Check if dev/staging/prod are at the same schema version
- **Use case:** "Which environments are ahead/behind? Is the pipeline in sync?"
- **Inputs:** None (queries all three environments)
- **Outputs:** Version matrix, which environments match, which are drifted
- **Format:** JSON + visual summary (table)
- **Example:** 
  ```
  dev: v42 ✓
  staging: v40 (2 migrations behind)
  prod: v40 ✓
  Status: DRIFTED (staging behind)
  ```

---

## Integration Points

### Tier Dependencies
- **Tier 2** calls **Tier 1** skills to gather schema data
- **Tier 3** calls **Tier 1** + **Tier 2** skills to compare and validate
- **Dev Support** output informs **CI/CD** checks (diagnostics help pipeline authors)

### Audience Workflows

**Developer (local troubleshooting):**
1. Run migration → fails
2. Call `oracle-migration-diff` (Tier 2) → see what's missing
3. Call `oracle-migration-status` (Tier 2) → see last successful migration
4. Option A: Manually fix and retry
5. Option B: Call `oracle-schema-reset` (Tier 2) → start fresh

**CI/CD Pipeline (pre-deploy):**
1. Pipeline triggers for staging deployment
2. Calls `oracle-pre-deploy-check` (Tier 3) with target=staging
3. If FAIL, calls `oracle-schema-compare-environments` (Tier 3) to get diff
4. Logs results, fails deployment with actionable error
5. Developer uses Tier 2 skills to investigate locally

**Release Engineer (multi-environment sync):**
1. Before prod release, calls `oracle-environment-sync-status` (Tier 3)
2. Sees staging is 2 migrations behind
3. Calls `oracle-schema-compare-environments` (Tier 3) to detail the gap
4. Decides: apply missing migrations to staging or roll back prod

---

## Success Criteria

1. ✓ Developers can troubleshoot failed migrations locally using Tier 2 skills
2. ✓ Pipelines can validate schema consistency before deployment (Tier 3)
3. ✓ Each skill has clear input/output contracts (JSON + docs)
4. ✓ Skills work across three environments (local XE + staging + prod)
5. ✓ Both ad-hoc (dev) and automated (pipeline) use cases supported

---

## Implementation Order

1. **Phase 1 (Tier 2):** Implement dev support skills (migration troubleshooting)
   - `oracle-migration-status`, `oracle-migration-diff`, `oracle-schema-conflict-detect`
   
2. **Phase 2 (Tier 2 cont.):** Complete dev support
   - `oracle-schema-reset`, `oracle-user-permissions`
   
3. **Phase 3 (Tier 3):** Implement CI/CD skills (environment validation)
   - `oracle-pre-deploy-check`, `oracle-schema-compare-environments`
   
4. **Phase 4 (Tier 3 cont.):** Complete CI/CD automation
   - `oracle-migration-validate`, `oracle-schema-drift-detect`, `oracle-environment-sync-status`

---

## Future Considerations

- **Tier 4 (Performance):** Query execution plans, slow query detection, index recommendations
- **Skill composition:** Create meta-skills that chain multiple base skills (e.g., "full deployment audit")
- **Multi-tenancy:** Support for multiple applications sharing same Oracle instance

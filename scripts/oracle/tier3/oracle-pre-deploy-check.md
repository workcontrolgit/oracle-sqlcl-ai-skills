# oracle-pre-deploy-check

Pre-deployment validation gating skill that orchestrates multiple validation checks into a single pass/fail decision for CI/CD pipelines.

## Purpose

Ensures target environment (staging/production) is ready for deployment by running:
- **Connectivity Check:** Database connection verification
- **Schema Drift Detection:** Manual schema changes (strict mode only)
- **Migration Status:** All expected migrations applied (strict mode only)
- **User Permissions:** Required privileges present (strict mode only)

Returns aggregated JSON report + markdown summary. Pipeline-ready for deployment gates.

## Parameters

| Parameter | Type | Default | Required | Description |
|-----------|------|---------|----------|-------------|
| TargetEnvironment | string | N/A | Yes | Deployment target: staging or production (NOT local) |
| ValidationMode | string | strict | No | strict (all 4 checks) or basic (connectivity only) |
| ReportFormat | string | combined | No | combined, json-only, or markdown-only |

## Environment Restrictions

- NOT supported: local (pre-deployment checks are for staging/prod only)
- Supported: staging, production
- Error if local specified: Pre-deployment checks are for staging/production only

## Validation Modes

### Strict Mode (default)
Runs all 4 checks: Connectivity, Schema Drift, Migration Status, User Permissions

### Basic Mode
Runs connectivity check only (quick CI/CD gate)

## Report Format

Returns JSON with Status, TargetEnvironment, ValidationMode, Timestamp, Checks, and Summary fields.

### Status Values
- DEPLOYMENT_READY: All checks passed
- DEPLOYMENT_BLOCKED: Any check failed
- ERROR: Execution error

### Exit Codes
- 0 = DEPLOYMENT_READY
- 1 = DEPLOYMENT_BLOCKED or ERROR

## Usage Examples

Windows PowerShell
Copyright (C) Microsoft Corporation. All rights reserved.

Install the latest PowerShell for new features and improvements! https://aka.ms/PSWindows

PS C:\apps\oracle> 

## Dependencies

- OracleConnection.psm1
- SchemaInspector.psm1
- OutputFormatter.psm1
- oracle-schema-conflict-detect.ps1 (tier2)
- oracle-migration-status.ps1 (tier2)
- oracle-user-permissions.ps1 (tier2)

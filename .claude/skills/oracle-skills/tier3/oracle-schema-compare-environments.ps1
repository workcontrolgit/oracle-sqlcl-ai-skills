param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("local", "staging", "production")]
    [string]$SourceEnvironment,

    [Parameter(Mandatory=$true)]
    [ValidateSet("local", "staging", "production")]
    [string]$TargetEnvironment,

    [Parameter(Mandatory=$false)]
    [ValidateSet("full", "subset")]
    [string]$ComparisonType = "full"
)

$sharedPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared"
Import-Module (Join-Path $sharedPath "OracleConnection.psm1") -Force
Import-Module (Join-Path $sharedPath "OutputFormatter.psm1") -Force
Import-Module (Join-Path $sharedPath "SchemaInspector.psm1") -Force

function Get-EnvironmentSchemaSnapshot {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("local", "staging", "production")]
        [string]$Environment,

        [Parameter(Mandatory=$false)]
        [ValidateSet("full", "subset")]
        [string]$ComparisonType = "full"
    )

    try {
        $schema = @{Tables = @(); Columns = @{}; Constraints = @{}}
        $tables = Get-TableList -Environment $Environment
        if ($null -eq $tables) { return $schema }
        if ($tables -isnot [object[]]) { $tables = @($tables) }

        foreach ($table in $tables) {
            $tableName = $table.Name
            if ([string]::IsNullOrEmpty($tableName)) { continue }
            $schema.Tables += $tableName

            $columns = Get-TableColumns -Environment $Environment -TableName $tableName
            if ($null -ne $columns) {
                if ($columns -isnot [object[]]) { $columns = @($columns) }
                $schema.Columns[$tableName] = $columns
            }

            if ($ComparisonType -eq "full") {
                $constraints = Get-TableConstraints -Environment $Environment -TableName $tableName
                if ($null -ne $constraints) {
                    if ($constraints -isnot [object[]]) { $constraints = @($constraints) }
                    $schema.Constraints[$tableName] = $constraints
                }
            }
        }
        return $schema
    } catch {
        Write-Error "Failed to get schema snapshot for $Environment : $_"
        return $null
    }
}

function Compare-EnvironmentSchemas {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$SourceSchema,

        [Parameter(Mandatory=$true)]
        [hashtable]$TargetSchema,

        [Parameter(Mandatory=$false)]
        [ValidateSet("full", "subset")]
        [string]$ComparisonType = "full"
    )

    try {
        $diffs = @()
        $comparison = @{
            Status = "SCHEMAS_MATCH"
            Summary = @{
                SourceTables = $SourceSchema.Tables.Count
                TargetTables = $TargetSchema.Tables.Count
                TablesMatch = 0
                MissingInTarget = 0
                ExtraInTarget = 0
                ColumnDifferences = 0
                ConstraintDifferences = 0
            }
        }

        # Check for missing tables in target
        foreach ($table in $SourceSchema.Tables) {
            if ($TargetSchema.Tables -notcontains $table) {
                $diffs += @{
                    Table = $table
                    Type = "MissingInTarget"
                    Details = "Table exists in source but not in target"
                }
                $comparison.Status = "SCHEMAS_DIFFER"
                $comparison.Summary.MissingInTarget += 1
            } else {
                $comparison.Summary.TablesMatch += 1
            }
        }

        # Check for extra tables in target
        foreach ($table in $TargetSchema.Tables) {
            if ($SourceSchema.Tables -notcontains $table) {
                $diffs += @{
                    Table = $table
                    Type = "ExtraInTarget"
                    Details = "Table exists in target but not in source"
                }
                $comparison.Status = "SCHEMAS_DIFFER"
                $comparison.Summary.ExtraInTarget += 1
            }
        }

        # Check for column differences (for tables that exist in both)
        foreach ($tableName in $SourceSchema.Tables) {
            if ($TargetSchema.Tables -notcontains $tableName) { continue }

            $sourceCols = if ($SourceSchema.Columns.ContainsKey($tableName)) {
                @($SourceSchema.Columns[$tableName] | ForEach-Object { $_.Name })
            } else {
                @()
            }

            $targetCols = if ($TargetSchema.Columns.ContainsKey($tableName)) {
                @($TargetSchema.Columns[$tableName] | ForEach-Object { $_.Name })
            } else {
                @()
            }

            foreach ($col in $sourceCols) {
                if ($targetCols -notcontains $col) {
                    $diffs += @{
                        Table = $tableName
                        Type = "ColumnMissing"
                        Details = "Column $col`: exists in source but not in target"
                    }
                    $comparison.Status = "SCHEMAS_DIFFER"
                    $comparison.Summary.ColumnDifferences += 1
                }
            }

            foreach ($col in $targetCols) {
                if ($sourceCols -notcontains $col) {
                    $diffs += @{
                        Table = $tableName
                        Type = "ColumnExtra"
                        Details = "Column $col`: exists in target but not in source"
                    }
                    $comparison.Status = "SCHEMAS_DIFFER"
                    $comparison.Summary.ColumnDifferences += 1
                }
            }
        }

        # Check for constraint differences if full comparison
        if ($ComparisonType -eq "full") {
            foreach ($tableName in $SourceSchema.Tables) {
                if ($TargetSchema.Tables -notcontains $tableName) { continue }

                $sourceConstraints = if ($SourceSchema.Constraints.ContainsKey($tableName)) {
                    @($SourceSchema.Constraints[$tableName] | ForEach-Object { $_.Name })
                } else {
                    @()
                }

                $targetConstraints = if ($TargetSchema.Constraints.ContainsKey($tableName)) {
                    @($TargetSchema.Constraints[$tableName] | ForEach-Object { $_.Name })
                } else {
                    @()
                }

                foreach ($constraint in $sourceConstraints) {
                    if ($targetConstraints -notcontains $constraint) {
                        $diffs += @{
                            Table = $tableName
                            Type = "ConstraintMissing"
                            Details = "Constraint $constraint`: exists in source but not in target"
                        }
                        $comparison.Status = "SCHEMAS_DIFFER"
                        $comparison.Summary.ConstraintDifferences += 1
                    }
                }

                foreach ($constraint in $targetConstraints) {
                    if ($sourceConstraints -notcontains $constraint) {
                        $diffs += @{
                            Table = $tableName
                            Type = "ConstraintExtra"
                            Details = "Constraint $constraint`: exists in target but not in source"
                        }
                        $comparison.Status = "SCHEMAS_DIFFER"
                        $comparison.Summary.ConstraintDifferences += 1
                    }
                }
            }
        }

        $comparison["Diffs"] = $diffs
        return $comparison
    } catch {
        Write-Error "Failed to compare schemas: $_"
        return $null
    }
}

try {
    # Validate that source and target environments differ
    if ($SourceEnvironment -eq $TargetEnvironment) {
        $result = @{
            Status = "ERROR"
            Message = "Source and target environments must be different"
            SourceEnvironment = $SourceEnvironment
            TargetEnvironment = $TargetEnvironment
            ComparisonType = $ComparisonType
        }
        $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
        $markdownOutput = "``````markdown`n"
        $markdownOutput += "- **Status**: ERROR`n"
        $markdownOutput += "- **Message**: Source and target environments must be different`n"
        $markdownOutput += "`n``````"
        Write-Output ($jsonOutput + "`n`n" + $markdownOutput)
        exit 1
    }

    # Retrieve schemas from both environments
    $sourceSchema = Get-EnvironmentSchemaSnapshot -Environment $SourceEnvironment -ComparisonType $ComparisonType
    if ($null -eq $sourceSchema) {
        $result = @{
            Status = "ERROR"
            Message = "Failed to retrieve schema from source environment"
            SourceEnvironment = $SourceEnvironment
            TargetEnvironment = $TargetEnvironment
        }
        $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
        $markdownOutput = "``````markdown`n"
        $markdownOutput += "- **Status**: ERROR`n"
        $markdownOutput += "- **Message**: Failed to retrieve schema from source environment`n"
        $markdownOutput += "`n``````"
        Write-Output ($jsonOutput + "`n`n" + $markdownOutput)
        exit 1
    }

    $targetSchema = Get-EnvironmentSchemaSnapshot -Environment $TargetEnvironment -ComparisonType $ComparisonType
    if ($null -eq $targetSchema) {
        $result = @{
            Status = "ERROR"
            Message = "Failed to retrieve schema from target environment"
            SourceEnvironment = $SourceEnvironment
            TargetEnvironment = $TargetEnvironment
        }
        $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
        $markdownOutput = "``````markdown`n"
        $markdownOutput += "- **Status**: ERROR`n"
        $markdownOutput += "- **Message**: Failed to retrieve schema from target environment`n"
        $markdownOutput += "`n``````"
        Write-Output ($jsonOutput + "`n`n" + $markdownOutput)
        exit 1
    }

    # Compare schemas
    $comparison = Compare-EnvironmentSchemas -SourceSchema $sourceSchema -TargetSchema $targetSchema -ComparisonType $ComparisonType
    if ($null -eq $comparison) {
        $result = @{
            Status = "ERROR"
            Message = "Failed to compare schemas"
            SourceEnvironment = $SourceEnvironment
            TargetEnvironment = $TargetEnvironment
        }
        $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
        $markdownOutput = "``````markdown`n"
        $markdownOutput += "- **Status**: ERROR`n"
        $markdownOutput += "- **Message**: Failed to compare schemas`n"
        $markdownOutput += "`n``````"
        Write-Output ($jsonOutput + "`n`n" + $markdownOutput)
        exit 1
    }

    # Build final result
    $result = @{
        Status = $comparison.Status
        SourceEnvironment = $SourceEnvironment
        TargetEnvironment = $TargetEnvironment
        ComparisonType = $ComparisonType
        Summary = $comparison.Summary
        Diffs = $comparison.Diffs
    }

    # Escape special characters in diff details for markdown
    $diffsForMarkdown = @()
    foreach ($diff in $result.Diffs) {
        $escapedDiff = @{}
        foreach ($key in $diff.Keys) {
            $value = $diff[$key]
            if ($value -is [string]) {
                $escapedValue = $value -replace '\\', '\\' -replace '\|', '\|'
                $escapedDiff[$key] = $escapedValue
            } else {
                $escapedDiff[$key] = $value
            }
        }
        $diffsForMarkdown += $escapedDiff
    }

    # Format JSON output
    $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"

    # Format markdown output
    $markdownOutput = "``````markdown`n"
    $markdownOutput += "| Aspect | Value |`n"
    $markdownOutput += "|--------|-------|`n"
    $markdownOutput += "| Source Environment | $SourceEnvironment |`n"
    $markdownOutput += "| Target Environment | $TargetEnvironment |`n"
    $markdownOutput += "| Source Tables | $($result.Summary.SourceTables) |`n"
    $markdownOutput += "| Target Tables | $($result.Summary.TargetTables) |`n"
    $markdownOutput += "| Matching Tables | $($result.Summary.TablesMatch) |`n"
    $markdownOutput += "| Status | $($result.Status) |`n"

    if ($result.Diffs.Count -gt 0) {
        $markdownOutput += "`n**Differences Found**: $($result.Diffs.Count)`n"
        $markdownOutput += (ConvertTo-MarkdownTable -Data $diffsForMarkdown)
    }

    $markdownOutput += "`n``````"

    Write-Output ($jsonOutput + "`n`n" + $markdownOutput)

    # Exit with appropriate code
    if ($result.Status -eq "SCHEMAS_MATCH") {
        exit 0
    } else {
        exit 1
    }
}
catch {
    $result = @{
        Status = "ERROR"
        Message = "Exception occurred during schema comparison"
        Error = $_.Exception.Message
        SourceEnvironment = $SourceEnvironment
        TargetEnvironment = $TargetEnvironment
    }
    $jsonOutput = "``````json`n" + (ConvertTo-DiagnosticJson -Result $result) + "`n``````"
    $markdownOutput = "``````markdown`n"
    $markdownOutput += "- **Status**: ERROR`n"
    $markdownOutput += "- **Message**: Schema comparison failed: $($_.Exception.Message)`n"
    $markdownOutput += "`n``````"
    Write-Output ($jsonOutput + "`n`n" + $markdownOutput)
    exit 1
}

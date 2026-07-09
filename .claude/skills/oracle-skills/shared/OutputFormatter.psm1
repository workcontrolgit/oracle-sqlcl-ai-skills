<#
.SYNOPSIS
    OutputFormatter module for formatting diagnostic output (JSON + Markdown)

.DESCRIPTION
    Provides functions to format diagnostic results for both human readability (markdown)
    and pipeline parsing (JSON). No external dependencies.

.FUNCTIONS
    - ConvertTo-MarkdownTable: Convert array of objects to markdown table
    - ConvertTo-DiagnosticJson: Convert hashtable to diagnostic JSON
    - Format-DiagnosticOutput: Combined JSON + markdown output block
    - Format-SuccessOutput: Format success diagnostic output (Status=PASS)
    - Format-FailureOutput: Format failure diagnostic output (Status=FAIL)
#>

<#
.SYNOPSIS
    Converts an array of objects to a markdown table

.DESCRIPTION
    Takes an array of PSObjects or hashtables and formats them as a markdown table
    with proper headers and row separators.

.PARAMETER Data
    Array of objects to convert to markdown table

.PARAMETER Properties
    Optional array of property names to include. If not specified, all properties are used.

.OUTPUTS
    [string] Formatted markdown table
#>
function ConvertTo-MarkdownTable {
    param(
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]]$Data,

        [Parameter(Mandatory=$false)]
        [string[]]$Properties
    )

    # Handle empty data
    if ($null -eq $Data -or $Data.Count -eq 0) {
        return ""
    }

    # Normalize to array
    if ($Data -is [hashtable]) {
        $Data = @($Data)
    }

    # Determine properties to use
    if ($null -eq $Properties -or $Properties.Count -eq 0) {
        # Get properties from first object
        $firstItem = $Data[0]
        if ($firstItem -is [hashtable]) {
            $Properties = @($firstItem.Keys)
        } else {
            $Properties = @($firstItem.PSObject.Properties.Name)
        }
    }

    # Build markdown table
    $lines = @()

    # Header row
    $headerRow = "| " + ($Properties -join " | ") + " |"
    $lines += $headerRow

    # Separator row
    $separatorRow = "| " + (($Properties | ForEach-Object { "---" }) -join " | ") + " |"
    $lines += $separatorRow

    # Data rows
    foreach ($item in $Data) {
        $rowValues = @()
        foreach ($prop in $Properties) {
            $value = ""
            if ($item -is [hashtable]) {
                $value = $item[$prop] -as [string]
            } else {
                $value = $item.$prop -as [string]
            }

            # Escape markdown special characters in table cells
            # Escape backslash first, then pipe
            $value = $value -replace '\\', '\\'
            $value = $value -replace '\|', '\|'

            $rowValues += $value
        }
        $dataRow = "| " + ($rowValues -join " | ") + " |"
        $lines += $dataRow
    }

    return $lines -join "`n"
}

<#
.SYNOPSIS
    Converts a hashtable to formatted diagnostic JSON

.DESCRIPTION
    Takes a hashtable (or PSObject) and converts it to indented JSON format
    suitable for diagnostic output and pipeline consumption.

.PARAMETER Result
    Hashtable or PSObject to convert to JSON

.OUTPUTS
    [string] Formatted JSON string
#>
function ConvertTo-DiagnosticJson {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Result
    )

    # Convert to JSON with indentation
    try {
        $json = $Result | ConvertTo-Json -Depth 10
        return $json
    }
    catch {
        Write-Error "Failed to convert result to JSON: $_"
        return @{} | ConvertTo-Json
    }
}

<#
.SYNOPSIS
    Formats diagnostic output as combined JSON and markdown blocks

.DESCRIPTION
    Takes a result hashtable and produces formatted output with:
    - A JSON code block (for pipeline parsing)
    - A markdown code block (for human readability)
    Blocks are separated by a blank line.

.PARAMETER Result
    Hashtable containing diagnostic result with optional Status, Message, and Data fields

.OUTPUTS
    [string] Combined JSON and markdown formatted output
#>
function Format-DiagnosticOutput {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Result
    )

    # Generate JSON block
    $jsonBlock = "``````json`n" + (ConvertTo-DiagnosticJson -Result $Result) + "`n``````"

    # Generate markdown block
    $markdownLines = @()
    $markdownLines += "``````markdown"

    # Add result properties as key-value pairs
    foreach ($key in $Result.Keys) {
        if ($key -ne "Data" -and $key -ne "Items") {
            $value = $Result[$key]
            if ($value -is [array]) {
                $markdownLines += "- **$key**: ($($value.Count) items)"
            } else {
                $markdownLines += "- **$key**: $value"
            }
        }
    }

    # Add Data or Items as table if present
    if ($Result.ContainsKey("Data") -and $null -ne $Result["Data"] -and $Result["Data"].Count -gt 0) {
        $markdownLines += ""
        $markdownLines += "## Data"
        $markdownLines += ""
        $markdownLines += (ConvertTo-MarkdownTable -Data $Result["Data"])
    } elseif ($Result.ContainsKey("Items") -and $null -ne $Result["Items"] -and $Result["Items"].Count -gt 0) {
        $markdownLines += ""
        $markdownLines += "## Items"
        $markdownLines += ""
        $markdownLines += (ConvertTo-MarkdownTable -Data $Result["Items"])
    }

    $markdownLines += "``````"
    $markdownBlock = $markdownLines -join "`n"

    # Combine blocks with blank line separator
    return $jsonBlock + "`n`n" + $markdownBlock
}

<#
.SYNOPSIS
    Formats output for successful diagnostic results

.DESCRIPTION
    Convenience wrapper around Format-DiagnosticOutput that adds Status=PASS
    and optionally a success message.

.PARAMETER Result
    Hashtable or array containing diagnostic result data

.PARAMETER Message
    Optional success message to include in output

.OUTPUTS
    [string] Formatted success diagnostic output
#>
function Format-SuccessOutput {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Result,

        [Parameter(Mandatory=$false)]
        [string]$Message
    )

    # Normalize Result to hashtable
    $resultHash = $Result
    if ($Result -is [array]) {
        $resultHash = @{ Data = $Result }
    } elseif ($Result -isnot [hashtable]) {
        $resultHash = @{ Result = $Result }
    }

    # Add Status and Message
    $resultHash["Status"] = "PASS"
    if ($Message) {
        $resultHash["Message"] = $Message
    }

    return Format-DiagnosticOutput -Result $resultHash
}

<#
.SYNOPSIS
    Formats output for failed diagnostic results

.DESCRIPTION
    Convenience wrapper around Format-DiagnosticOutput that adds Status=FAIL
    and optionally an error message.

.PARAMETER Result
    Hashtable or array containing diagnostic result data (typically error details)

.PARAMETER Message
    Optional error message to include in output

.OUTPUTS
    [string] Formatted failure diagnostic output
#>
function Format-FailureOutput {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Result,

        [Parameter(Mandatory=$false)]
        [string]$Message
    )

    # Normalize Result to hashtable
    $resultHash = $Result
    if ($Result -is [array]) {
        $resultHash = @{ Details = $Result }
    } elseif ($Result -isnot [hashtable]) {
        $resultHash = @{ Result = $Result }
    }

    # Add Status and Message
    $resultHash["Status"] = "FAIL"
    if ($Message) {
        $resultHash["Message"] = $Message
    }

    return Format-DiagnosticOutput -Result $resultHash
}

# Export public functions
Export-ModuleMember -Function @(
    'ConvertTo-MarkdownTable',
    'ConvertTo-DiagnosticJson',
    'Format-DiagnosticOutput',
    'Format-SuccessOutput',
    'Format-FailureOutput'
)

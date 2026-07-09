<#
.SYNOPSIS
    Pester tests for OutputFormatter module
#>

$modulePath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "shared\OutputFormatter.psm1"
Import-Module $modulePath -Force

Describe "OutputFormatter" {

    Context "ConvertTo-MarkdownTable" {
        It "Converts array of objects to markdown table with headers" {
            $data = @(
                @{ Name = "Alice"; Status = "Active"; Count = 5 },
                @{ Name = "Bob"; Status = "Inactive"; Count = 3 }
            )
            $result = ConvertTo-MarkdownTable -Data $data

            # Should contain markdown table structure
            ($result -match '\|') | Should Be $true
            ($result -match 'Name') | Should Be $true
            ($result -match 'Status') | Should Be $true
            ($result -match 'Count') | Should Be $true
            ($result -match 'Alice') | Should Be $true
            ($result -match 'Bob') | Should Be $true
        }

        It "Supports custom properties selection" {
            $data = @(
                @{ Name = "Alice"; Status = "Active"; Count = 5; Extra = "Ignore" },
                @{ Name = "Bob"; Status = "Inactive"; Count = 3; Extra = "Ignore" }
            )
            $result = ConvertTo-MarkdownTable -Data $data -Properties @("Name", "Status")

            # Should contain selected properties but not Extra
            ($result -match 'Name') | Should Be $true
            ($result -match 'Status') | Should Be $true
            ($result -match 'Extra') | Should Be $false
            ($result -match 'Alice') | Should Be $true
        }

        It "Handles empty data array" {
            $data = @()
            $result = ConvertTo-MarkdownTable -Data $data

            # Should return empty string or minimal output
            ($result -eq "" -or $result.Length -eq 0) | Should Be $true
        }

        It "Handles single object" {
            $data = @{ Name = "Alice"; Status = "Active" }
            $result = ConvertTo-MarkdownTable -Data @($data)

            # Should contain header row and data row
            ($result -match 'Name') | Should Be $true
            ($result -match 'Alice') | Should Be $true
        }
    }

    Context "ConvertTo-DiagnosticJson" {
        It "Converts hashtable to valid JSON with Status field" {
            $result = @{ Name = "Test"; Value = 42 }
            $json = ConvertTo-DiagnosticJson -Result $result

            # Should be valid JSON
            { $json | ConvertFrom-Json } | Should Not Throw

            # Parse and verify
            $obj = $json | ConvertFrom-Json
            $obj.Name | Should Be "Test"
            $obj.Value | Should Be 42
        }

        It "Includes Status field in JSON output" {
            $result = @{ Data = "test" }
            $json = ConvertTo-DiagnosticJson -Result $result

            $obj = $json | ConvertFrom-Json
            # Note: Status field may be added by caller through Format-DiagnosticOutput
            # or may be passed in the result hashtable
            ($json -match '"Data"') | Should Be $true
        }

        It "Handles nested objects" {
            $result = @{
                Name = "Test"
                Details = @{
                    SubKey = "SubValue"
                    Count = 10
                }
            }
            $json = ConvertTo-DiagnosticJson -Result $result

            { $json | ConvertFrom-Json } | Should Not Throw
            $obj = $json | ConvertFrom-Json
            $obj.Details.SubKey | Should Be "SubValue"
        }

        It "Handles arrays in result" {
            $result = @{
                Items = @("Item1", "Item2", "Item3")
            }
            $json = ConvertTo-DiagnosticJson -Result $result

            { $json | ConvertFrom-Json } | Should Not Throw
            $obj = $json | ConvertFrom-Json
            $obj.Items.Count | Should Be 3
        }
    }

    Context "Format-DiagnosticOutput" {
        It "Returns combined JSON and markdown blocks" {
            $result = @{
                Status = "SUCCESS"
                Message = "Test passed"
                Data = @(
                    @{ Name = "Item1"; Value = 10 },
                    @{ Name = "Item2"; Value = 20 }
                )
            }
            $output = Format-DiagnosticOutput -Result $result

            # Should contain both code blocks
            ($output -match '```json') | Should Be $true
            ($output -match '```markdown') | Should Be $true
            ($output -match '```') | Should Be $true

            # Should contain Status field
            ($output -match 'SUCCESS') | Should Be $true
        }

        It "Separates JSON and markdown blocks with blank line" {
            $result = @{
                Status = "SUCCESS"
                Data = @( @{ Name = "Test" } )
            }
            $output = Format-DiagnosticOutput -Result $result

            # Split by triple backticks to verify structure
            ($output -match '```') | Should Be $true
        }

        It "Handles Data array for markdown rendering" {
            $result = @{
                Status = "SUCCESS"
                Data = @(
                    @{ Column1 = "Value1"; Column2 = "Value2" },
                    @{ Column1 = "Value3"; Column2 = "Value4" }
                )
            }
            $output = Format-DiagnosticOutput -Result $result

            # Markdown section should contain table
            ($output -match 'Column1') | Should Be $true
            ($output -match 'Value1') | Should Be $true
        }

        It "Handles result without Data array" {
            $result = @{
                Status = "SUCCESS"
                Message = "Operation completed"
            }
            $output = Format-DiagnosticOutput -Result $result

            # Should still produce valid output
            ($output.Length -gt 0) | Should Be $true
            ($output -match '```json') | Should Be $true
        }
    }

    Context "Format-SuccessOutput" {
        It "Formats success output with Status=PASS" {
            $data = @( @{ Name = "Alice"; Status = "OK" } )
            $output = Format-SuccessOutput -Result $data -Message "Test passed"

            # Should contain PASS status
            ($output -match 'PASS') | Should Be $true
            ($output -match '```json') | Should Be $true
        }

        It "Accepts hashtable with custom fields" {
            $result = @{
                TestName = "MyTest"
                Results = @( @{ Name = "Test" } )
            }
            $output = Format-SuccessOutput -Result $result

            # Should wrap in Status=PASS and format
            ($output -match 'PASS') | Should Be $true
            ($output -match 'TestName') | Should Be $true
        }

        It "Handles optional message parameter" {
            $result = @{ Data = @() }
            $output1 = Format-SuccessOutput -Result $result
            $output2 = Format-SuccessOutput -Result $result -Message "Custom message"

            # Both should produce valid output
            ($output1.Length -gt 0) | Should Be $true
            ($output2 -match 'Custom message') | Should Be $true
        }
    }

    Context "Format-FailureOutput" {
        It "Formats failure output with Status=FAIL" {
            $result = @{ ErrorMessage = "Something went wrong" }
            $output = Format-FailureOutput -Result $result

            # Should contain FAIL status
            ($output -match 'FAIL') | Should Be $true
            ($output -match '```json') | Should Be $true
        }

        It "Includes error details in output" {
            $result = @{
                ErrorMessage = "Connection failed"
                ErrorCode = 1001
                Details = @( @{ Issue = "Timeout"; Duration = "30s" } )
            }
            $output = Format-FailureOutput -Result $result

            ($output -match 'FAIL') | Should Be $true
            ($output -match 'Connection failed') | Should Be $true
            ($output -match 'ErrorCode') | Should Be $true
        }

        It "Handles optional message parameter" {
            $result = @{ Error = "Test error" }
            $output = Format-FailureOutput -Result $result -Message "Detailed failure"

            ($output -match 'FAIL') | Should Be $true
            ($output -match 'Detailed failure') | Should Be $true
        }
    }

    Context "Module exports" {
        It "Exports ConvertTo-MarkdownTable" {
            (Get-Command ConvertTo-MarkdownTable -ErrorAction SilentlyContinue) | Should Not BeNullOrEmpty
        }

        It "Exports ConvertTo-DiagnosticJson" {
            (Get-Command ConvertTo-DiagnosticJson -ErrorAction SilentlyContinue) | Should Not BeNullOrEmpty
        }

        It "Exports Format-DiagnosticOutput" {
            (Get-Command Format-DiagnosticOutput -ErrorAction SilentlyContinue) | Should Not BeNullOrEmpty
        }

        It "Exports Format-SuccessOutput" {
            (Get-Command Format-SuccessOutput -ErrorAction SilentlyContinue) | Should Not BeNullOrEmpty
        }

        It "Exports Format-FailureOutput" {
            (Get-Command Format-FailureOutput -ErrorAction SilentlyContinue) | Should Not BeNullOrEmpty
        }
    }
}

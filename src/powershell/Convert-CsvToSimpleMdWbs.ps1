<#
.SYNOPSIS
    CSVファイルを読み込み、ユーザー定義の採番ロジックに基づいてWBS番号を付与し、
    その番号でソートした上で、simple-md-wbs形式のMarkdownファイルを生成します。
.DESCRIPTION
    このスクリプトは、docs/92_logic_of_numbering.md の詳細設計書に厳密に従います。
.NOTES
    Version: 12.2.0 (Fixed ParserError)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$InputCsvPath,

    [Parameter(Mandatory=$false)]
    [string]$OutputMdPath
)

begin {
    # Set UI Culture to English for consistent error messages
    [System.Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
    
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"
    Write-Verbose "Starting script: $($MyInvocation.MyCommand.Name)"

    # Resolve output path if it's not absolute
    if (-not $OutputMdPath) {
        # Default path if not provided
        if ($PSScriptRoot) {
            $OutputMdPath = Join-Path $PSScriptRoot "..\..\test_outputs\output.md"
        } else {
            # Fallback for environments where $PSScriptRoot is not available
            $OutputMdPath = Join-Path $PWD "test_outputs\output.md"
        }
    }
    if (-not [System.IO.Path]::IsPathRooted($OutputMdPath)) {
        $OutputMdPath = Join-Path $PWD $OutputMdPath
    }
    $OutputMdPath = [System.IO.Path]::GetFullPath($OutputMdPath)
    Write-Verbose "Output path resolved to: $OutputMdPath"
}

process {
    try {
        # === ステップ1: CSV読み込みと、H1要素の分離 ===
        Write-Verbose "Step 1: Reading CSV and segregating H1 element..."
        $csvData = Import-Csv -Path $InputCsvPath -Encoding UTF8
        if ($null -eq $csvData) { return }

        $headerItem = $csvData | Select-Object -First 1
        $bodyItems = $csvData | Select-Object -Skip 1

        if ($null -eq $headerItem) {
            throw "Project title (H1 element, the first row of the CSV) was not found."
        }
        
        # === ステップ2: WBSボディの項目で、WBS番号を付与 ===
        Write-Verbose "Step 2: Processing and numbering WBS body items..."
        $processedItems = [System.Collections.Generic.List[object]]::new()
        
        # H2, H3, H4, Task counters. Start H2 from 1.
        $counters = @{ H2 = 1; H3 = 1; H4 = 1; Task = 1 }
        $lastWbsNumber = @{ H2 = 0; H3 = 0; H4 = 0 }

        foreach ($row in $bodyItems) {
            $currentLevel = $null
            $itemText = $null

            if (-not [string]::IsNullOrEmpty($row.'大分類'))     { $currentLevel = "H2"; $itemText = $row.'大分類' }
            elseif (-not [string]::IsNullOrEmpty($row.'中分類')) { $currentLevel = "H3"; $itemText = $row.'中分類' }
            elseif (-not [string]::IsNullOrEmpty($row.'小分類')) { $currentLevel = "H4"; $itemText = $row.'小分類' }
            elseif (-not [string]::IsNullOrEmpty($row.'タスクアイテム'))   { $currentLevel = "Task"; $itemText = $row.'タスクアイテム' }
            else { continue }

            $wbsNumber = ""
            switch ($currentLevel) {
                "H2" {
                    $lastWbsNumber.H2 = $counters.H2
                    $wbsNumber = "{0:D2}.00.00.000" -f $lastWbsNumber.H2
                    $counters.H2++
                    $counters.H3 = 1; $counters.H4 = 1; $counters.Task = 1
                }
                "H3" {
                    $lastWbsNumber.H3 = $counters.H3
                    $wbsNumber = "{0:D2}.{1:D2}.00.000" -f $lastWbsNumber.H2, $lastWbsNumber.H3
                    $counters.H3++
                    $counters.H4 = 1; $counters.Task = 1
                }
                "H4" {
                    $lastWbsNumber.H4 = $counters.H4
                    $wbsNumber = "{0:D2}.{1:D2}.{2:D2}.000" -f $lastWbsNumber.H2, $lastWbsNumber.H3, $lastWbsNumber.H4
                    $counters.H4++
                    $counters.Task = 1
                }
                "Task" {
                    $wbsNumber = "{0:D2}.{1:D2}.{2:D2}.{3:D3}" -f $lastWbsNumber.H2, $lastWbsNumber.H3, $lastWbsNumber.H4, $counters.Task
                    $counters.Task++
                }
            }

            $processedItems.Add([PSCustomObject]@{ WbsNumber = $wbsNumber; Level = $currentLevel; ItemText = $itemText; CsvRow = $row })
            Write-Verbose "Assigned [$wbsNumber] to '$itemText'"
        }

        # === ステップ3: WBS番号で全ての項目を並べ替え ===
        Write-Verbose "Step 3: Sorting all items by the generated WBS Number..."
        $sortedItems = $processedItems | Sort-Object @{Expression={ [System.Version]$_.WbsNumber }}

        # === ステップ4: ソート済みリストからMarkdownを生成 ===
        Write-Verbose "Step 4: Generating final Markdown from sorted list..."
        $markdownOutputLines = [System.Collections.Generic.List[string]]::new()

        $h1Title = $headerItem.'大分類'
        $h1AttributeString = "H1_Info,$($headerItem.'中分類'),$($headerItem.'小分類'),,,,$($headerItem.'タスクアイテム'),,,,,,"
        $markdownOutputLines.Add("# $h1Title")
        $markdownOutputLines.Add("%% $h1AttributeString")
        
        foreach ($item in $sortedItems) {
            $attributeValues = @(
                $item.CsvRow.'番号', # Use original '番号' for 'ユーザー記述ID'
                $item.CsvRow.'開始入力', $item.CsvRow.'終了入力', $item.CsvRow.'日数入力', $item.CsvRow.'関連種別',
                $item.CsvRow.'関連番号', $item.CsvRow.'開始実績', $item.CsvRow.'修了実績', $item.CsvRow.'進捗実績', $item.CsvRow.'担当者名',
                $item.CsvRow.'担当組織', $item.CsvRow.'最終更新', $item.CsvRow.'コメント'
            )
            $attributeString = $attributeValues -join ','
            $isAttributeEmpty = (-not ($attributeValues -join '').Trim())

            $markdownOutputLines.Add("") # Blank line before each item
            switch ($item.Level) {
                "H2"   { $markdownOutputLines.Add("## $($item.ItemText)") }
                "H3"   { $markdownOutputLines.Add("### $($item.ItemText)") }
                "H4"   { $markdownOutputLines.Add("#### $($item.ItemText)") }
                "Task" { $markdownOutputLines.Add("- $($item.ItemText)") }
            }
            if (-not $isAttributeEmpty) {
                if ($item.Level -eq "Task") { 
                    $markdownOutputLines[-1] += " <!-- $attributeString -->" 
                }
                else { 
                    $markdownOutputLines.Add("%% $attributeString")
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

end {
    Write-Verbose "Finalizing script and writing to file..."
    if ($markdownOutputLines.Count -gt 0) {
        $outputDirectory = Split-Path -Path $OutputMdPath -Parent
        if (-not (Test-Path $outputDirectory)) { 
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null 
        }
        # Add a newline at the end of the file
        $fileContent = ($markdownOutputLines | Out-String) + [Environment]::NewLine
        Set-Content -Path $OutputMdPath -Value $fileContent -Encoding UTF8BOM -Force
        Write-Host "Successfully generated markdown file: $OutputMdPath" -ForegroundColor Green
    }
}
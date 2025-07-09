<#
.SYNOPSIS
    Generates hierarchical WBS numbers for a CSV file based on its structure.

.DESCRIPTION
    This script reads a CSV file where the WBS structure is defined by task items followed by their summary categories (bottom-up).
    It automatically assigns a hierarchical WBS number (e.g., 1.1.1.1) to each row based on the specified rules.
    The script assumes the 4th line of the CSV is the header and data starts from the 5th line.

.PARAMETER InputPath
    The absolute path to the source CSV file. Must be UTF-8 with BOM encoded.

.PARAMETER OutputPath
    The absolute path for the generated CSV file. The output will be UTF-8 with BOM encoded.

.EXAMPLE
    PS C:> .\Generate-WbsNumbers.ps1 -InputPath "C:\temp\source.csv" -OutputPath "C:\temp\wbs_numbered.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

begin {
    Write-Verbose "Initialization started."
    # WBS Numbering Counters
    $L1 = 0
    $L2 = 0
    $L3 = 0
    $L4 = 0
}

process {
    Write-Verbose "Processing file: $InputPath"

    try {
        # Manually define the headers to ensure correctness
        $headers = @(
            '番号','大分類','中分類','小分類','タスクアイテム','関連種別','関連番号','関連タスクアイテム',
            '関連有無','コメント','進捗日数','作業遅延','開始遅延','遅延日数','担当組織','担当者名',
            'フラグ','最終更新','開始入力','終了入力','日数入力','開始計画','終了計画','日数計画',
            '進捗実績','開始実績','修了実績'
        )

        # Import the CSV, skipping the first 4 lines and applying the predefined headers
        $data = Import-Csv -Path $InputPath -Encoding UTF8 -Header $headers | Select-Object -Skip 4

        $outputData = [System.Collections.Generic.List[PSObject]]::new()

        foreach ($row in $data) {
            $newRow = $row | Select-Object *

            # Skip row if all key columns are empty
            if ([string]::IsNullOrWhiteSpace($row.'大分類') -and
                [string]::IsNullOrWhiteSpace($row.'中分類') -and
                [string]::IsNullOrWhiteSpace($row.'小分類') -and
                [string]::IsNullOrWhiteSpace($row.'タスクアイテム')) {
                continue
            }

            # Determine the type of row and generate the WBS number
            if (-not [string]::IsNullOrWhiteSpace($row.'タスクアイテム')) {
                $L4++
                $wbsNumber = "$L1.$L2.$L3.$L4"
                $newRow.番号 = $wbsNumber
            }
elseif (-not [string]::IsNullOrWhiteSpace($row.'小分類')) {
                $L3++
                $L4 = 0
                $wbsNumber = "$L1.$L2.$L3.0"
                $newRow.番号 = $wbsNumber
            }
elseif (-not [string]::IsNullOrWhiteSpace($row.'中分類')) {
                $L2++
                $L3 = 0
                $L4 = 0
                $wbsNumber = "$L1.$L2.0.0"
                $newRow.番号 = $wbsNumber
            }
elseif (-not [string]::IsNullOrWhiteSpace($row.'大分類')) {
                $L1++
                $L2 = 0
                $L3 = 0
                $L4 = 0
                $wbsNumber = "$L1.0.0.0"
                $newRow.番号 = $wbsNumber
            }

            $outputData.Add($newRow)
        }

        # Export the data with the new '番号' column to the output file
        $outputData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -Force
        Write-Verbose "Successfully processed $($outputData.Count) rows and saved to $OutputPath"
    }
    catch {
        Write-Error "An error occurred: $_"
        throw
    }
}

end {
    Write-Verbose "Script finished."
}

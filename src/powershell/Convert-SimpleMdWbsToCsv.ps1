<#
.SYNOPSIS
    Converts a simple-md-wbs file to a CSV file based on the RENUM logic.
#>
# using module は、他のどのコードよりも先に、スクリプトの先頭に記述する必要があります
using module ".\Modules\MyCommonFunctions\MyCommonFunctions.psm1"

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFilePath,

    [Parameter(Mandatory = $false)]
    [string]$OutputCsvPath = '.\wbs_output.csv'
)

begin {
    # PowerShell 2.0 環境などで System.Collections.Generic.List が見つからない場合があるため、
    # System.Core.dll を明示的にロードすることを試みます。
    # 注意: このスクリプトはクラス定義 (WbsElementNode) など PowerShell 5.0 以降の機能を
    # 共通モジュール経由で使用しています。根本的な互換性のためには PowerShell の
    # バージョンアップを強く推奨します。
    Add-Type -AssemblyName System.Core -ErrorAction SilentlyContinue

    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    Write-Verbose "Starting script: $($MyInvocation.MyCommand.Name)"
    # Import-Module は不要になるため、begin ブロックから削除またはコメントアウトします
    # try { ... Import-Module ... } catch { ... } のブロックを削除
    Write-Verbose "Initialization complete. Module is loaded via 'using module'."
}

process {
    try {
        Write-Verbose "--- Phase 1: Gathering all WBS items and creating ID map ---"

        # PowerShell 5.0 未満の互換性を考慮し、New-Object を使用 (ただし WbsElementNode の解決は別問題)
        # $wbsItems = [System.Collections.Generic.List[WbsElementNode]]::new()
        $wbsItems = New-Object "System.Collections.Generic.List[WbsElementNode]"
        # $idMap = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $idMap = New-Object "System.Collections.Generic.Dictionary[string, string]" ([System.StringComparer]::OrdinalIgnoreCase)
        $currentHierarchyLevel = 0

        Reset-InternalWbsCounters

        $fileContent = Get-Content -Path $InputFilePath -Encoding UTF8

        for ($i = 0; $i -lt $fileContent.Count; $i++) {
            $line = $fileContent[$i]
            # ... (ここから下の for ループ内のロジックは変更なし) ...
            $itemLevel = 0
            $isTask = $false
            $itemText = ''

            if ($line -match '^\s*#+\s+([^<]+?)(?:\s+<!--.*)?$') {
                $itemLevel = ($line -split ' ')[0].Length
                $itemText = $matches[1].Trim()
                $isTask = $false
                Update-InternalWbsCounters -Level $itemLevel
                $currentHierarchyLevel = $itemLevel
                $attributeString = ''
                if (($i + 1) -lt $fileContent.Count) {
                    $nextLineIndex = $i + 1
                    $nextLineContent = $fileContent[$nextLineIndex]
                    if ([string]::IsNullOrWhiteSpace($nextLineContent)) {
                        if (($nextLineIndex + 1) -lt $fileContent.Count) {
                            $afterNextLineIndex = $nextLineIndex + 1
                            $afterNextLineContent = $fileContent[$afterNextLineIndex]
                            if ($afterNextLineContent -match '^\s*%%(.*)') {
                                $attributeString = $matches[1].Trim()
                                $i = $afterNextLineIndex
                            }
                        }
                    } elseif ($nextLineContent -match '^\s*%%(.*)') {
                        $attributeString = $matches[1].Trim()
                        $i = $nextLineIndex
                    }
                }
            } elseif ($line -match '^\s*-\s+(.*?)(?:\s+<!--(.*?)-->)?$') {
                $isTask = $true
                $itemLevel = $currentHierarchyLevel
                $itemText = $matches[1].Trim()
                if ($matches.Count -gt 2 -and -not [string]::IsNullOrWhiteSpace($matches[2])) {
                    $attributeString = $matches[2].Trim()
                } else {
                    $attributeString = ''
                }
            } else {
                if (-not [string]::IsNullOrWhiteSpace($line) -and $line -notmatch '^\s*<!--.*-->\s*$') {
                    Write-Verbose "Skipping line (Not a recognized WBS item): $line"
                }
                continue
            }

            $item = [WbsElementNode]::new()
            $item.HierarchyLevel = $itemLevel
            $item.ItemText = $itemText.Trim()
            $item.IsTask = $isTask
            $item.Attributes = New-Object string[] 13
            $rawSplitAttributes = $attributeString.Split(',', 13) | ForEach-Object { $_.Trim() }
            for ($j = 0; $j -lt $rawSplitAttributes.Length -and $j -lt 13; $j++) {
                $item.Attributes[$j] = $rawSplitAttributes[$j]
            }
            $item.SystemId = Get-NextInternalSystemId -Level $itemLevel -IsTask $isTask
            $item.HierarchicalId = Get-NextInternalHierarchicalId -Level $itemLevel -IsTask $isTask
            $item.UserDefinedId = $item.Attributes[0]
            $item.PredecessorUserDefinedId = $item.Attributes[5]
            if (-not [string]::IsNullOrEmpty($item.UserDefinedId)) {
                if ($idMap.ContainsKey($item.UserDefinedId)) {
                    Write-Warning "Duplicate User-Defined ID found: '$($item.UserDefinedId)'."
                } else {
                    $idMap[$item.UserDefinedId] = $item.SystemId
                    Write-Verbose "Mapped User ID '$($item.UserDefinedId)' to System ID '$($item.SystemId)'"
                }
            }
            <#
            # --- デバッグここから ---
            Write-Host "--------------------------------------------------" -ForegroundColor Magenta
            Write-Host "Line $($i+1): '$line'"
            Write-Host ("  -&gt; Parsed Text  : " + $item.ItemText) -ForegroundColor Cyan
            Write-Host ("  -&gt; IsTask?      : " + $item.IsTask) -ForegroundColor Cyan
            Write-Host ("  -&gt; Hierarchy    : " + $item.HierarchyLevel) -ForegroundColor Cyan
            Write-Host ("  -&gt; UserDefinedId: " + $item.UserDefinedId) -ForegroundColor Cyan
            # --- デバッグここまで ---
            #>
            $wbsItems.Add($item)
        }

        Write-Verbose "--- Phase 2: Preparing for CSV export ---"
        $csvOutput = foreach ($item in $wbsItems) {
            # [最終修正] IsTask と HierarchyLevel を厳密に組み合わせて判定する
            $大分類, $中分類, $小分類, $タスクアイテム = '', '', '', ''

            if ($item.IsTask) {
                # IsTask が true の場合は、無条件でタスクアイテムとする
                $タスクアイテム = $item.ItemText
            }
            else {
                # IsTask が false の場合は、カテゴリまたはプロジェクトなので、階層レベルで判断する
                switch ($item.HierarchyLevel) {
                    1 { $タスクアイテム = $item.ItemText }
                    2 { $大分類       = $item.ItemText }
                    3 { $中分類       = $item.ItemText }
                    4 { $小分類       = $item.ItemText }
                }
            }
            <#
            # --- デバッグここから ---
            $debugLine = "CSV Row Gen: Text='{0}', IsTask='{1}', Level='{2}' -&gt; 大='{3}', 中='{4}', 小='{5}', アイテム='{6}'" -f `
                $item.ItemText, $item.IsTask, $item.HierarchyLevel, $大分類, $中分類, $小分類, $タスクアイテム
            Write-Host $debugLine -ForegroundColor Yellow
            # --- デバッグここまで ---
            #>

            [PSCustomObject]@{
                タスクID           = $item.UserDefinedId
                番号               = $item.HierarchicalId
                大分類             = $大分類
                中分類             = $中分類
                小分類             = $小分類
                タスクアイテム       = $タスクアイテム
                # ... (以下の属性は変更なし) ...
                関連種別           = $item.Attributes[4]
                関連番号           = $item.PredecessorUserDefinedId
                関連タスクアイテム   = ''
                関連有無           = ''
                コメント             = $item.Attributes[12]
                進捗日数           = ''
                作業遅延           = ''
                開始遅延           = ''
                遅延日数           = ''
                担当組織           = $item.Attributes[10]
                担当者名           = $item.Attributes[9]
                フラグ             = ''
                最終更新           = $item.Attributes[11]
                開始入力           = $item.Attributes[1]
                終了入力           = $item.Attributes[2]
                日数入力           = $item.Attributes[3]
                開始計画           = ''
                終了計画           = ''
                日数計画           = ''
                進捗実績           = $item.Attributes[8]
                開始実績           = $item.Attributes[6]
                修了実績           = $item.Attributes[7]
            }
        }

        # CSV出力
        $outputDirectory = Split-Path -Path $OutputCsvPath -Parent
        if (-not ([string]::IsNullOrEmpty($outputDirectory)) -and (-not (Test-Path -Path $outputDirectory))) {
            Write-Verbose "Creating output directory: $outputDirectory"
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        }
        $csvOutput | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "Successfully exported WBS data to: $OutputCsvPath" -ForegroundColor Green
    }
    catch {
        Write-Error "An unhandled error occurred: $($_.Exception.Message)"
    }
}

end {
    Write-Verbose "Script finished."
}
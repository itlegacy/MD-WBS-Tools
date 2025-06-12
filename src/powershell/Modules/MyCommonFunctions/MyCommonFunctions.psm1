Set-StrictMode -Version Latest
# MyCommonFunctions.psm1
<#
.SYNOPSIS
    Provides common functions for the MD-WBS-Tools project.
.DESCRIPTION
    This module provides common functions for the MD-WBS-Tools project.
#>

# モジュールスコープでカウンターを定義
$script:counters = @{
    L1Counter = 0 # Project counter (will effectively always be 0 for the ID "00.00.00.00")
    L2Counter = 0 # 大分類カウンター
    L3Counter = 0 # 中分類カウンター
    L4Counter = 0 # 小分類カウンター
    TaskCounter = 0 # タスクカウンター
}
# 現在の階層の値をID生成のために保持 (ゼロ埋め2桁文字列)
$script:currentLevelCounters = @{
    L1 = "00" # Consistent string initialization, though L1 ID is hardcoded in Get-DecodedAndMappedAttribute
    L2 = 0
    L3 = 0
    L4 = 0
}

# =============================================================================
# 内部クラス定義と関数定義 (スクリプトの先頭に移動)
# =============================================================================

# --- 内部クラス定義 ---
# WBSの各アイテムの情報をメモリ内で保持するためのクラス
class WbsElementNode {
    [int]$HierarchyLevel
    [string]$ItemText
    [string[]]$Attributes
    [string]$UserDefinedId
    [string]$PredecessorUserDefinedId
    [string]$SystemId
    [string]$HierarchicalId
    [string]$ResolvedPredecessorSystemId
    [bool]$IsTask
}

# --- 内部関数定義 ---
# スクリプト内で閉じたカウンター管理
$script:InternalWbsCounters = @{ L1 = 0; L2 = 0; L3 = 0; L4 = 0; Task = 0 }

function Reset-InternalWbsCounters {
    $script:InternalWbsCounters = @{ L1 = 0; L2 = 0; L3 = 0; L4 = 0; Task = 0 }
}

function Update-InternalWbsCounters {
    param([int]$Level)
    for ($i = $Level + 1; $i -le 4; $i++) { $script:InternalWbsCounters["L$i"] = 0 }
    $script:InternalWbsCounters.Task = 0
    if ($Level -ge 1 -and $Level -le 4) { $script:InternalWbsCounters["L$Level"]++ }
}

function Get-NextInternalSystemId {
    param([int]$Level, [bool]$IsTask)
    $parts = @()
    for ($i = 1; $i -le $Level; $i++) { $parts += $script:InternalWbsCounters["L$i"] }
    if ($IsTask) {
        $script:InternalWbsCounters.Task++
        $parts += $script:InternalWbsCounters.Task
    }
    return $parts -join '.'
}

function Get-NextInternalHierarchicalId {
    param([int]$Level, [bool]$IsTask)
    $l1 = "{0:D2}" -f $script:InternalWbsCounters.L1
    $l2 = "{0:D2}" -f $script:InternalWbsCounters.L2
    $l3 = "{0:D2}" -f $script:InternalWbsCounters.L3
    if ($IsTask) {
        $taskNum = "{0:D2}" -f $script:InternalWbsCounters.Task
        return "$l1.$l2.$l3.$taskNum"
    } else {
        switch ($Level) {
            1 { return "$l1.00.00.00" }
            2 { return "$l1.$l2.00.00" }
            3 { return "$l1.$l2.$l3.00" }
            4 { return "$l1.$l2.$l3.00" } # H4の階層IDはL3と同じ暫定仕様 (docs/12_wbs_task_syntax_specification.md にH4の明確な階層ID仕様がないため)
            default {
                Write-Warning "Get-NextInternalHierarchicalId: Unexpected Level '$Level' for a non-task item. Returning '00.00.00.00'."
                return "00.00.00.00"
            }
        }
    }
}

function Get-DecodedAndMappedAttribute {
    param (
        [int]$level,
        [string]$itemType
    )

    switch ($level) {
        1 { # Project (H1)
            $script:counters.L2Counter = 0; $script:currentLevelCounters.L2 = "00"
            $script:counters.L3Counter = 0; $script:currentLevelCounters.L3 = "00"
            $script:counters.L4Counter = 0; $script:currentLevelCounters.L4 = "00"
            $script:counters.TaskCounter = 0
            return "00.00.00.00"
        }
        2 { # 大分類 (H2)
            $script:counters.L2Counter++
            $script:currentLevelCounters.L2 = "{0:D2}" -f $script:counters.L2Counter
            $script:counters.L3Counter = 0; $script:currentLevelCounters.L3 = "00"
            $script:counters.L4Counter = 0; $script:currentLevelCounters.L4 = "00"
            $script:counters.TaskCounter = 0
            return "$($script:currentLevelCounters.L2).00.00.00"
        }
        3 { # 中分類 (H3)
            $script:counters.L3Counter++
            $script:currentLevelCounters.L3 = "{0:D2}" -f $script:counters.L3Counter
            $script:counters.L4Counter = 0; $script:currentLevelCounters.L4 = "00"
            $script:counters.TaskCounter = 0
            return "$($script:currentLevelCounters.L2).$($script:currentLevelCounters.L3).00.00"
        }
        4 { # 小分類 (H4)
            $script:counters.L4Counter++
            $script:currentLevelCounters.L4 = "{0:D2}" -f $script:counters.L4Counter
            $script:counters.TaskCounter = 0
            return "$($script:currentLevelCounters.L2).$($script:currentLevelCounters.L3).$($script:currentLevelCounters.L4).00"
        }
        5 { # Task
            $script:counters.TaskCounter++
            $taskSeqSegment = "{0:D2}" -f $script:counters.TaskCounter
            return "$($script:currentLevelCounters.L2).$($script:currentLevelCounters.L3).$($script:currentLevelCounters.L4).$taskSeqSegment"
        }
    }
    return "error.id.generation" # エラーケース
}

function ConvertTo-AttributeObject {
    [CmdletBinding()] # -Verbose を使えるようにする
    param ([string]$AttributeString)

    # --- ここからデバッグコード ---
    Write-Host "Debug: Inside ConvertTo-SimpleMdWbsAttributeString" -ForegroundColor Yellow
    Write-Host "  CsvRowItem object type: $($CsvRowItem.GetType().FullName)" -ForegroundColor Yellow
    Write-Host "  CsvRowItem properties (PSObject.Properties):" -ForegroundColor Yellow
    $CsvRowItem.PSObject.Properties | ForEach-Object {
        Write-Host "    Name: '$($_.Name)', Value: '$($_.Value)', TypeNameOfValue: '$($_.TypeNameOfValue)'" -ForegroundColor Cyan
    }

    $propertyNameToCheck = 'ユーザー記述ID'
    if ($CsvRowItem.PSObject.Properties[$propertyNameToCheck]) {
        Write-Host "  Property '$propertyNameToCheck' FOUND. Value: '$($CsvRowItem.$propertyNameToCheck)'" -ForegroundColor Green
    } else {
        Write-Host "  Property '$propertyNameToCheck' NOT FOUND on CsvRowItem." -ForegroundColor Red
        Write-Warning "  Property '$propertyNameToCheck' was not found on the CsvRowItem object passed to ConvertTo-SimpleMdWbsAttributeString."
    }
    # --- デバッグコードここまで ---

    Write-Verbose "ConvertTo-AttributeObject: Received AttributeString: '$AttributeString'"

    if ([string]::IsNullOrWhiteSpace($AttributeString)) {
        Write-Verbose "ConvertTo-AttributeObject: AttributeString is null or whitespace. Returning null."
        return $null
    }
    $decodedString = [System.Web.HttpUtility]::HtmlDecode($AttributeString)
    Write-Verbose "ConvertTo-AttributeObject: DecodedString: '$decodedString'"

    $rawAttributes = $decodedString.Split(',')
    Write-Verbose "ConvertTo-AttributeObject: RawAttributes count: $($rawAttributes.Count)"
    for ($j = 0; $j -lt $rawAttributes.Count; $j++) {
        Write-Verbose "ConvertTo-AttributeObject: rawAttributes[$j]: '$($rawAttributes[$j])'"
    }

    # ★フィールド数チェックと警告
    # IDのみの場合は警告しない (Count=1)
    # 完全に空の属性文字列も警告しない (これは関数の先頭でnullチェック済み)
    if ($rawAttributes.Count -gt 1 -and $rawAttributes.Count -ne 13) {
        Write-Warning "Attribute field count is $($rawAttributes.Count), which is not the expected 13. This may cause data misalignment. Attribute string: '$AttributeString'"
    }

    # simple-md-wbs 仕様書の13属性を明示的に初期化
    $itemObject = [PSCustomObject]@{
        UserDefinedId            = "" # 属性1
        StartDateInput           = "" # 属性2
        EndDateInput             = "" # 属性3
        DurationInput            = "" # 属性4
        DependencyType           = "" # 属性5
        PredecessorUserDefinedId = "" # 属性6
        ActualStartDate          = "" # 属性7
        ActualEndDate            = "" # 属性8
        Progress                 = "" # 属性9
        Assignee                 = "" # 属性10
        Organization             = "" # 属性11
        LastUpdatedDate          = "" # 属性12
        ItemComment              = "" # 属性13
    }

    # 各属性をインデックスに基づいて割り当て
    $propertyMap = @{
        0 = "UserDefinedId"
        1 = "StartDateInput"
        2 = "EndDateInput"
        3 = "DurationInput"
        4 = "DependencyType"
        5 = "PredecessorUserDefinedId"
        6 = "ActualStartDate"
        7 = "ActualEndDate"
        8 = "Progress"
        9 = "Assignee"
        10 = "Organization"
        11 = "LastUpdatedDate"
    }

    foreach ($index in $propertyMap.Keys | Sort-Object) {
        if ($rawAttributes.Count -gt $index) {
            $propertyName = $propertyMap[$index]
            $value = $rawAttributes[$index].Trim()
            $itemObject.$propertyName = $value
            Write-Verbose ("  Index {0}: {1} set to '{2}'" -f $index, $propertyName, $value)
        } else {
            # フィールドが存在しない場合もログを残す（任意）
            # Write-Verbose "  Index $index: $($propertyMap[$index]) not found in rawAttributes."
        }
    }

    # コメントは13番目の要素 (インデックス12) 以降すべて
    if ($rawAttributes.Count -gt 12) {
        $itemObject.ItemComment = ($rawAttributes[12..($rawAttributes.Count - 1)] | ForEach-Object {$_.Trim()}) -join ','
        Write-Verbose "  Index 12+: ItemComment set to '$($itemObject.ItemComment)'"
    } else {
        Write-Verbose "ItemComment remains empty as attribute count is 12 or less."
    }

    return $itemObject
}

function Reset-WbsCounters {
    $script:counters.L1Counter = 0 # Though L1 ID is fixed to 00.00.00.00
    $script:counters.L2Counter = 0
    $script:counters.L3Counter = 0
    $script:counters.L4Counter = 0
    $script:counters.TaskCounter = 0
    $script:currentLevelCounters.L1 = "00" # Fixed segment for project
    $script:currentLevelCounters.L2 = "00"
    $script:currentLevelCounters.L3 = "00"
    $script:currentLevelCounters.L4 = "00"
}

# フェーズ 2

function ConvertTo-SimpleMdWbsAttributeString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [psobject]$CsvRowItem
    )

    Write-Verbose "ConvertTo-SimpleMdWbsAttributeString: Processing CsvRowItem with UserDefinedId '$($CsvRowItem.'タスクID')'"

    # simple-md-wbs 仕様書の13属性の順序で値を格納する配列を準備
    # CSVの列名からsimple-md-wbsの属性へのマッピングが必要
    # このマッピングは docs/10_requirements_definition.yaml の output_csv_columns.source_simplemdwbs を参照
    # 例: $CsvRowItem.'ユーザー記述ID' はそのまま UserDefinedId になる
    #     $CsvRowItem.'開始入力' はそのまま StartDateInput になる
    #     $CsvRowItem.'担当者名' は Assignee になる
    #     ...など

    # 13属性の正しい順序で値を格納する配列
    $attributeValues = New-Object string[] 13

    # マッピング例 (docs/10_requirements_definition.yaml と docs/12_wbs_task_syntax_specification.md を参照して正確に定義)
    # CSVの列名が存在しない場合は空文字列とする処理も必要。

    # No.1: ユーザー記述ID
    $attributeValues[0] = if ($CsvRowItem.PSObject.Properties.Name -contains 'タスクID') { $CsvRowItem.'タスクID' } else { "" }
    # No.2: 開始日（入力）
    $attributeValues[1] = if ($CsvRowItem.PSObject.Properties.Name -contains '開始入力') { $CsvRowItem.'開始入力' } else { "" }
    # No.3: 終了日（入力）
    $attributeValues[2] = if ($CsvRowItem.PSObject.Properties.Name -contains '終了入力') { $CsvRowItem.'終了入力' } else { "" }
    # No.4: 日数（入力）
    $attributeValues[3] = if ($CsvRowItem.PSObject.Properties.Name -contains '日数入力') { $CsvRowItem.'日数入力' } else { "" }
    # No.5: 関連タスク種別
    $attributeValues[4] = if ($CsvRowItem.PSObject.Properties.Name -contains '関連種別') { $CsvRowItem.'関連種別' } else { "" }
    # No.6: 関連タスクID (CSVの「関連番号」列に対応)
    $attributeValues[5] = if ($CsvRowItem.PSObject.Properties.Name -contains '関連番号') { $CsvRowItem.'関連番号' } else { "" }
    # No.7: 開始日（実績）
    $attributeValues[6] = if ($CsvRowItem.PSObject.Properties.Name -contains '開始実績') { $CsvRowItem.'開始実績' } else { "" }
    # No.8: 終了日（実績）
    $attributeValues[7] = if ($CsvRowItem.PSObject.Properties.Name -contains '修了実績') { $CsvRowItem.'修了実績' } else { "" }
    # No.9: 進捗率
    $attributeValues[8] = if ($CsvRowItem.PSObject.Properties.Name -contains '進捗実績') { $CsvRowItem.'進捗実績' } else { "" }
    # No.10: 担当者
    $attributeValues[9] = if ($CsvRowItem.PSObject.Properties.Name -contains '担当者名') { $CsvRowItem.'担当者名' } else { "" }
    # No.11: 担当組織
    $attributeValues[10] = if ($CsvRowItem.PSObject.Properties.Name -contains '担当組織') { $CsvRowItem.'担当組織' } else { "" }
    # No.12: 最終更新日
    $attributeValues[11] = if ($CsvRowItem.PSObject.Properties.Name -contains '最終更新') { $CsvRowItem.'最終更新' } else { "" }
    # No.13: コメント
    $attributeValues[12] = if ($CsvRowItem.PSObject.Properties.Name -contains 'コメント') { $CsvRowItem.'コメント' } else { "" }
    # 配列をカンマで結合して返す
    $attributeString = $attributeValues -join ','
    Write-Verbose "ConvertTo-SimpleMdWbsAttributeString: Generated attribute string: '$attributeString'"
    return $attributeString
}

function Get-SimpleMdWbsHierarchyPrefix {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$HierarchyLevel, # 1:Project, 2:Category1(H2), 3:Category2(H3), 4:Category3(H4), 5:Task

        [Parameter(Mandatory = $true)]
        [ValidateSet("Project", "Category1", "Category2", "Category3", "Task")]
        [string]$ItemType
    )

    Write-Verbose "Get-SimpleMdWbsHierarchyPrefix: Level '$HierarchyLevel', ItemType '$ItemType'"
    $prefix = ""
    switch ($HierarchyLevel) {
        1 { $prefix = "# " }       # Project (H1)
        2 { $prefix = "## " }      # Category1 (H2)
        3 { $prefix = "### " }     # Category3 (H3)
        4 { $prefix = "#### " }    # Category4 (H4)
        5 { $prefix = "- " }       # Task (List Item)
        default {
            Write-Warning "Get-SimpleMdWbsHierarchyPrefix: Invalid HierarchyLevel '$HierarchyLevel'. Returning empty prefix."
        }
    }
    Write-Verbose "Get-SimpleMdWbsHierarchyPrefix: Returning prefix '$prefix'"
    return $prefix
}

$functionsToExport = @(
    'Get-DecodedAndMappedAttribute',
    'ConvertTo-AttributeObject',
    'Reset-WbsCounters',
    'ConvertTo-SimpleMdWbsAttributeString',
    'Get-SimpleMdWbsHierarchyPrefix',
    'Reset-InternalWbsCounters',
    'Update-InternalWbsCounters',
    'Get-NextInternalSystemId',
    'Get-NextInternalHierarchicalId'
)
Export-ModuleMember -Function $functionsToExport
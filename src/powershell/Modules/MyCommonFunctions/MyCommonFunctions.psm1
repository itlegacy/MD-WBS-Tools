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

Export-ModuleMember -Function Get-DecodedAndMappedAttribute, ConvertTo-AttributeObject, Reset-WbsCounters
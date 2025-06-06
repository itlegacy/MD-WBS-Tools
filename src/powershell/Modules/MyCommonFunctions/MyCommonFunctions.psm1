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
            # Project ID is always 00.00.00.00
            # Reset all subordinate counters and current path segments
            $script:counters.L2Counter = 0
            $script:currentLevelCounters.L2 = "00"
            $script:counters.L3Counter = 0
            $script:currentLevelCounters.L3 = "00"
            $script:counters.L4Counter = 0
            $script:currentLevelCounters.L4 = "00"
            $script:counters.TaskCounter = 0
            return "00.00.00.00"
        }
        2 { # 大分類 (H2)
            $script:counters.L2Counter++
            $script:currentLevelCounters.L2 = "{0:D2}" -f $script:counters.L2Counter
            # Reset lower-level counters and current path segments
            $script:counters.L3Counter = 0
            $script:currentLevelCounters.L3 = "00"
            $script:counters.L4Counter = 0
            $script:currentLevelCounters.L4 = "00"
            $script:counters.TaskCounter = 0
            return "$($script:currentLevelCounters.L2).00.00.00"
        }
        3 { # 中分類 (H3)
            $script:counters.L3Counter++
            $script:currentLevelCounters.L3 = "{0:D2}" -f $script:counters.L3Counter
            # Reset lower-level counters and current path segments
            $script:counters.L4Counter = 0
            $script:currentLevelCounters.L4 = "00"
            $script:counters.TaskCounter = 0
            return "$($script:currentLevelCounters.L2).$($script:currentLevelCounters.L3).00.00"
        }
        4 { # 小分類 (H4)
            $script:counters.L4Counter++
            $script:currentLevelCounters.L4 = "{0:D2}" -f $script:counters.L4Counter
            # Reset lower-level counter
            $script:counters.TaskCounter = 0
            return "$($script:currentLevelCounters.L2).$($script:currentLevelCounters.L3).$($script:currentLevelCounters.L4).00"
        }
        5 { # Task
            $script:counters.TaskCounter++
            $taskSeqSegment = "{0:D2}" -f $script:counters.TaskCounter
            return "$($script:currentLevelCounters.L2).$($script:currentLevelCounters.L3).$($script:currentLevelCounters.L4).$($taskSeqSegment)"
        }
    }
    return "00.00.00.00" # Default or error, aligned with max 4 segments for Task
}

function ConvertTo-AttributeObject {
    [CmdletBinding()] # Added for -Verbose support
    param ([string]$AttributeString)

    Write-Verbose "ConvertTo-AttributeObject: Received AttributeString: '$AttributeString'"

    if ([string]::IsNullOrWhiteSpace($AttributeString)) {
        Write-Verbose "ConvertTo-AttributeObject: AttributeString is null or whitespace. Returning null."
        return $null
    }
    $decodedString = [System.Web.HttpUtility]::HtmlDecode($AttributeString)
    Write-Verbose "ConvertTo-AttributeObject: DecodedString: '$decodedString'"
    
    # Splitはするが、Trimは各値を取得する際に個別に行う
    $rawAttributes = $decodedString.Split(',')
    Write-Verbose "ConvertTo-AttributeObject: RawAttributes count: $($rawAttributes.Count)"
    for ($j = 0; $j -lt $rawAttributes.Count; $j++) {
        Write-Verbose "ConvertTo-AttributeObject: rawAttributes[$j]: '$($rawAttributes[$j])'"
    }
    
    # PSCustomObject を直接生成する
    # プロパティ名は、最終的にメインスクリプトの $item オブジェクトやCSVヘッダーと整合性が取れるように
    # simple-md-wbs 仕様書のフィールド名をベースに英語表記・キャメルケースなどを検討
    $itemObject = [PSCustomObject]@{
        UserDefinedId            = "" # 1
        StartDateInput           = "" # 2
        EndDateInput             = "" # 3
        DurationInput            = "" # 4
        DependencyType           = "" # 5
        PredecessorUserDefinedId = "" # 6
        ActualStartDate          = "" # 7
        ActualEndDate            = "" # 8 (NEW)
        Progress                 = "" # 9
        Assignee                 = "" # 10
        Organization             = "" # 11
        LastUpdatedDate          = "" # 12 (NEW)
        ItemComment              = "" # 13
    }

    # 各属性をインデックスに基づいて割り当て
    if ($rawAttributes.Count -gt 0)  { $itemObject.UserDefinedId            = $rawAttributes[0].Trim(); Write-Verbose "Set UserDefinedId = '$($itemObject.UserDefinedId)'" }
    if ($rawAttributes.Count -gt 1)  { $itemObject.StartDateInput           = $rawAttributes[1].Trim(); Write-Verbose "Set StartDateInput = '$($itemObject.StartDateInput)'" }
    if ($rawAttributes.Count -gt 2)  { $itemObject.EndDateInput             = $rawAttributes[2].Trim(); Write-Verbose "Set EndDateInput = '$($itemObject.EndDateInput)'" }
    if ($rawAttributes.Count -gt 3)  { $itemObject.DurationInput            = $rawAttributes[3].Trim(); Write-Verbose "Set DurationInput = '$($itemObject.DurationInput)'" }
    if ($rawAttributes.Count -gt 4)  { $itemObject.DependencyType           = $rawAttributes[4].Trim(); Write-Verbose "Set DependencyType = '$($itemObject.DependencyType)'" }
    if ($rawAttributes.Count -gt 5)  { $itemObject.PredecessorUserDefinedId = $rawAttributes[5].Trim(); Write-Verbose "Set PredecessorUserDefinedId = '$($itemObject.PredecessorUserDefinedId)'" }
    if ($rawAttributes.Count -gt 6)  { $itemObject.ActualStartDate          = $rawAttributes[6].Trim(); Write-Verbose "Set ActualStartDate = '$($itemObject.ActualStartDate)'" }
    if ($rawAttributes.Count -gt 7)  { $itemObject.ActualEndDate            = $rawAttributes[7].Trim(); Write-Verbose "Set ActualEndDate = '$($itemObject.ActualEndDate)'" }
    if ($rawAttributes.Count -gt 8)  { $itemObject.Progress                 = $rawAttributes[8].Trim(); Write-Verbose "Set Progress = '$($itemObject.Progress)'" }
    if ($rawAttributes.Count -gt 9)  { $itemObject.Assignee                 = $rawAttributes[9].Trim(); Write-Verbose "Set Assignee = '$($itemObject.Assignee)'" }
    if ($rawAttributes.Count -gt 10) { $itemObject.Organization             = $rawAttributes[10].Trim(); Write-Verbose "Set Organization = '$($itemObject.Organization)'" }
    if ($rawAttributes.Count -gt 11) { $itemObject.LastUpdatedDate          = $rawAttributes[11].Trim(); Write-Verbose "Set LastUpdatedDate = '$($itemObject.LastUpdatedDate)'" }
    
    # コメント属性 (13番目の属性) の処理
    # simple-md-wbs 仕様書 3.3 によると、コメントは13番目のフィールド以降すべて。
    # 属性フィールドが少なくとも13個存在する場合にのみコメント処理を行う
    if ($rawAttributes.Count -ge 13) {
        # インデックス12 (13番目の要素) から最後までを結合
        # $rawAttributes[12] が存在し、かつそれが空文字列でない場合、またはそれ以降にも要素がある場合に結合する
        if ($rawAttributes.Count -gt 12 -or ($rawAttributes.Count -eq 13 -and -not [string]::IsNullOrWhiteSpace($rawAttributes[12]))) {
            $itemObject.ItemComment = ($rawAttributes[12..($rawAttributes.Count - 1)] | ForEach-Object { $_.Trim() }) -join ','
            Write-Verbose "Set ItemComment = '$($itemObject.ItemComment)' from $($rawAttributes.Count - 12) fields starting at index 12"
        } else {
            # 属性が13個あるが、13番目の要素が空またはスペースのみの場合
            $itemObject.ItemComment = "" # 明示的に空にする
            Write-Verbose "ItemComment set to empty as the 13th field (index 12) is empty or whitespace."
        }
    } else {
        Write-Verbose "ItemComment remains empty as attribute count is less than 13."
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
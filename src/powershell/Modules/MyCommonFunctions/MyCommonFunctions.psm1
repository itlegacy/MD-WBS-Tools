# MyCommonFunctions.psm1
Set-StrictMode -Version Latest
<#
.SYNOPSIS
    Provides common functions for the MD-WBS-Tools project.
.DESCRIPTION
    This module provides common functions for the MD-WBS-Tools project.
#>

# モジュールスコープでカウンターを定義
$script:counters = @{
    L1   = 0
    L2   = 0
    L3   = 0
    L4   = 0
    Task = 0
}
# ★ $currentLevelCounters もモジュールスクリプトスコープで初期化
$script:currentLevelCounters = @{
    L1 = 0
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
            $script:counters.L1++
            $script:counters.L2 = 0; $script:counters.L3 = 0; $script:counters.L4 = 0; $script:counters.Task = 0
            # ★ $script:currentLevelCounters を使用
            $script:currentLevelCounters.L1 = $script:counters.L1
            $script:currentLevelCounters.L2 = 0; $script:currentLevelCounters.L3 = 0; $script:currentLevelCounters.L4 = 0
            return ("{0:D2}.00.00.00" -f $script:currentLevelCounters.L1)
        }
        2 { # 大分類 (H2)
            $script:counters.L2++
            $script:counters.L3 = 0; $script:counters.L4 = 0; $script:counters.Task = 0
            # ★ $script:currentLevelCounters を使用
            $script:currentLevelCounters.L2 = $script:counters.L2
            $script:currentLevelCounters.L3 = 0; $script:currentLevelCounters.L4 = 0
            return ("{0:D2}.{1:D2}.00.00" -f $script:currentLevelCounters.L1, $script:currentLevelCounters.L2)
        }
        3 { # 中分類 (H3)
            $script:counters.L3++
            $script:counters.L4 = 0; $script:counters.Task = 0
            # ★ $script:currentLevelCounters を使用
            $script:currentLevelCounters.L3 = $script:counters.L3
            $script:currentLevelCounters.L4 = 0
            return ("{0:D2}.{1:D2}.{2:D2}.00" -f $script:currentLevelCounters.L1, $script:currentLevelCounters.L2, $script:currentLevelCounters.L3)
        }
        4 { # 小分類 (H4)
            $script:counters.L4++
            $script:counters.Task = 0
            # ★ $script:currentLevelCounters を使用
            $script:currentLevelCounters.L4 = $script:counters.L4
            return ("{0:D2}.{1:D2}.{2:D2}.{3:D2}" -f $script:currentLevelCounters.L1, $script:currentLevelCounters.L2, $script:currentLevelCounters.L3, $script:currentLevelCounters.L4)
        }
        5 { # Task
            $script:counters.Task++
            # ★ $script:currentLevelCounters を参照
            $idL1 = "{0:D2}" -f $script:currentLevelCounters.L1
            $idL2 = if ($script:currentLevelCounters.L2 -gt 0) { "{0:D2}" -f $script:currentLevelCounters.L2 } else { "00" }
            $idL3 = if ($script:currentLevelCounters.L3 -gt 0) { "{0:D2}" -f $script:currentLevelCounters.L3 } else { "00" }
            $idL4 = if ($script:currentLevelCounters.L4 -gt 0) { "{0:D2}" -f $script:currentLevelCounters.L4 } else { "00" }
            return ("{0}.{1}.{2}.{3}.{4:D2}" -f $idL1, $idL2, $idL3, $idL4, $script:counters.Task)
        }
    }
    return "00.00.00.00.00" # Default or error
}

function ConvertTo-AttributeObject {
    param ([string]$AttributeString)
    if ([string]::IsNullOrWhiteSpace($AttributeString)) {
        return $null
    }
    $decodedString = [System.Web.HttpUtility]::HtmlDecode($AttributeString)
    # Splitはするが、Trimは各値を取得する際に個別に行う
    $rawAttributes = $decodedString.Split(',')

    # PSCustomObject を直接生成する (ハッシュテーブルを介さない)
    $itemObject = [PSCustomObject]@{
        UserDefinedId            = ""
        EndDate                  = ""
        Duration                 = ""
        DependencyType           = ""
        PredecessorUserDefinedId = ""
        Status                   = ""
        Progress                 = ""
        Assignee                 = ""
        Organization             = ""
        ActualStartDate          = ""
        ItemComment              = ""
    }

    if ($rawAttributes.Count -gt 0)  { $itemObject.UserDefinedId = $rawAttributes[0].Trim() }
    if ($rawAttributes.Count -gt 1)  { $itemObject.EndDate = $rawAttributes[1].Trim() }
    if ($rawAttributes.Count -gt 2)  { $itemObject.Duration = $rawAttributes[2].Trim() }
    if ($rawAttributes.Count -gt 3)  { $itemObject.DependencyType = $rawAttributes[3].Trim() }
    if ($rawAttributes.Count -gt 4)  { $itemObject.PredecessorUserDefinedId = $rawAttributes[4].Trim() }
    if ($rawAttributes.Count -gt 5)  { $itemObject.Status = $rawAttributes[5].Trim() }
    if ($rawAttributes.Count -gt 6)  { $itemObject.Progress = $rawAttributes[6].Trim() }
    if ($rawAttributes.Count -gt 7)  { $itemObject.Assignee = $rawAttributes[7].Trim() }      # Index 7
    if ($rawAttributes.Count -gt 8)  { $itemObject.Organization = $rawAttributes[8].Trim() }  # Index 8
    if ($rawAttributes.Count -gt 9)  { $itemObject.ActualStartDate = $rawAttributes[9].Trim()} # Index 9

    if ($rawAttributes.Count -gt 10) {
        $itemObject.ItemComment = ($rawAttributes[10..($rawAttributes.Count - 1)] | ForEach-Object {$_.Trim()}) -join ','
    } elseif ($rawAttributes.Count -eq 11) { # 属性がちょうど11個(ID+9属性+コメント1つ)
        $itemObject.ItemComment = $rawAttributes[10].Trim()
    }

    # ★デバッグ表示追加
    Write-Host "AttributeString: $AttributeString"
    Write-Host "Parsed Object Properties:"
    $itemObject.PSObject.Properties | ForEach-Object { Write-Host "  $($_.Name) = '$($_.Value)'" }

    return $itemObject # PSCustomObject を返す
}

function Reset-WbsCounters {
    $script:counters.L1 = 0; $script:counters.L2 = 0; $script:counters.L3 = 0; $script:counters.L4 = 0; $script:counters.Task = 0
    $script:currentLevelCounters.L1 = 0; $script:currentLevelCounters.L2 = 0; $script:currentLevelCounters.L3 = 0; $script:currentLevelCounters.L4 = 0
    Write-Verbose "WBS counters have been reset."
}

Export-ModuleMember -Function Get-DecodedAndMappedAttribute, ConvertTo-AttributeObject, Reset-WbsCounters
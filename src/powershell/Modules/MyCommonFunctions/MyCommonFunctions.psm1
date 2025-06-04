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

    # PSCustomObject を直接生成する
    # プロパティ名は、最終的にメインスクリプトの $item オブジェクトやCSVヘッダーと整合性が取れるように
    # simple-md-wbs 仕様書のフィールド名をベースに英語表記・キャメルケースなどを検討
    $itemObject = [PSCustomObject]@{
        UserDefinedId            = "" # 1. ユーザー記述ID
        StartDateInput           = "" # 2. 開始日（入力）
        EndDateInput             = "" # 3. 終了日（入力）
        DurationInput            = "" # 4. 日数（入力）
        DependencyType           = "" # 5. 関連タスク種別
        PredecessorUserDefinedId = "" # 6. 関連タスクID
        ActualStartDate          = "" # 7. 開始日（実績）
        ActualEndDate            = "" # 8. 終了日（実績）  ★NEW
        Progress                 = "" # 9. 進捗率
        Assignee                 = "" # 10. 担当者
        Organization             = "" # 11. 担当組織
        LastUpdatedDate          = "" # 12. 最終更新日    ★NEW (以前のStatusの位置から移動)
        ItemComment              = "" # 13. コメント
    }

    # 各属性をインデックスに基づいて割り当て
    if ($rawAttributes.Count -gt 0)  { $itemObject.UserDefinedId = $rawAttributes[0].Trim() }
    if ($rawAttributes.Count -gt 1)  { $itemObject.StartDateInput = $rawAttributes[1].Trim() }
    if ($rawAttributes.Count -gt 2)  { $itemObject.EndDateInput = $rawAttributes[2].Trim() }
    if ($rawAttributes.Count -gt 3)  { $itemObject.DurationInput = $rawAttributes[3].Trim() }
    if ($rawAttributes.Count -gt 4)  { $itemObject.DependencyType = $rawAttributes[4].Trim() }
    if ($rawAttributes.Count -gt 5)  { $itemObject.PredecessorUserDefinedId = $rawAttributes[5].Trim() }
    if ($rawAttributes.Count -gt 6)  { $itemObject.ActualStartDate = $rawAttributes[6].Trim() }
    if ($rawAttributes.Count -gt 7)  { $itemObject.ActualEndDate = $rawAttributes[7].Trim() }      # ★NEW
    if ($rawAttributes.Count -gt 8)  { $itemObject.Progress = $rawAttributes[8].Trim() }
    if ($rawAttributes.Count -gt 9)  { $itemObject.Assignee = $rawAttributes[9].Trim() }
    if ($rawAttributes.Count -gt 10) { $itemObject.Organization    = $rawAttributes[10].Trim() }

    # 11. 最終更新日 (インデックス 11)
    if ($rawAttributes.Count -gt 11) { $itemObject.LastUpdatedDate = $rawAttributes[11].Trim() }
    else                             { $itemObject.LastUpdatedDate = "" }

    # 12. コメント (インデックス 12 以降)
    if ($rawAttributes.Count -gt 12) {
        $itemObject.ItemComment = ($rawAttributes[12..($rawAttributes.Count - 1)] | ForEach-Object {$_.Trim()}) -join ','
    }
    # elseif ($rawAttributes.Count -eq 12) { # 属性がちょうど13個の場合、コメントはインデックス12の要素
    #    $itemObject.ItemComment = $rawAttributes[12].Trim()
    # } # この elseif は上記の if ($rawAttributes.Count -gt 12) に包含されるので不要。
      # Countが13の時、[12..12]となり、正しく動作する。
    else { # 属性が12個以下の場合、コメントは空
        $itemObject.ItemComment = ""
    }

    # ★ デバッグ出力 (テスト時のみ有効化)
    Write-Host "AttributeString: [$AttributeString]"
    Write-Host "rawAttributes.Count: $($rawAttributes.Count)"
    Write-Host "LastUpdatedDate: $($itemObject.LastUpdatedDate)"
    Write-Host "ItemComment: $($itemObject.ItemComment)"
    # $itemObject.PSObject.Properties | ForEach-Object { Write-Host "  $($_.Name) = '$($_.Value)'" }

    return $itemObject
}

function Reset-WbsCounters {
    $script:counters.L1 = 0; $script:counters.L2 = 0; $script:counters.L3 = 0; $script:counters.L4 = 0; $script:counters.Task = 0
    $script:currentLevelCounters.L1 = 0; $script:currentLevelCounters.L2 = 0; $script:currentLevelCounters.L3 = 0; $script:currentLevelCounters.L4 = 0
    # Write-Verbose "WBS counters have been reset."
}

Export-ModuleMember -Function Get-DecodedAndMappedAttribute, ConvertTo-AttributeObject, Reset-WbsCounters
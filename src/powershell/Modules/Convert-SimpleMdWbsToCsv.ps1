<#
.SYNOPSIS
    Converts a simple-md-wbs file to a CSV file.
.DESCRIPTION
    This script parses a simple-md-wbs file and outputs a CSV file.
#>
[CmdletBinding()]

param (
    [Parameter(Mandatory=$true, HelpMessage="入力するsimple-md-wbsファイルのパス")]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    [string]$InputFilePath,

    [Parameter(Mandatory=$false, HelpMessage="出力するCSVファイルのパス")]
    [string]$OutputCsvPath = ".\wbs_output.csv" # デフォルト値をより一般的に
)

$ErrorActionPreference = "Stop" # スクリプト全体のエラー処理方法を設定

begin {
    # 初期化処理
    Write-Verbose "Starting script Convert-SimpleMdWbsToCsv.ps1"
}

process {
    # ファイル読み込み、行ごとのパース処理
    try {
        # ファイルを読み込む
        $lines = Get-Content -Path $InputFilePath -ErrorAction Stop
        Write-Verbose "Successfully read file: $InputFilePath" # ログ出力
    }
    catch {
        Write-Error "Failed to read file: $($_.Exception.Message)"
        exit 1
    }


    for ($i = 0; $i -lt $lines.Count; $i++) {
        $currentLine = $lines[$i]
        $nextLine = if (($i + 1) -lt $lines.Count) { $lines[$i+1] } else { $null }
        $afterNextLine = if (($i + 2) -lt $lines.Count) { $lines[$i+2] } else { $null }


        $item = [PSCustomObject]@{
            DisplaySortKey = ""
            Category1Name = "" # プロジェクト名 (H1)
            Category2Name = "" # 大分類 (H2)
            Category3Name = "" # 中分類 (H3)
            Category4Name = "" # 小分類 (H4)
            TaskName = ""      # または最下層カテゴリ名/タスク名
            UserDefinedId = ""
            EndDate = ""
            Duration = ""
            DependencyType = ""
            PredecessorUserDefinedId = ""
            Status = ""
            Progress = ""
            Assignee = ""
            Organization = ""
            ActualStartDate = ""
            ItemComment = ""
            ItemType = "Unknown"
            HierarchyLevel = 0
        }

        if ($currentLine -match "^#\s+(.*)") { # H1 (Project)
            $item.ItemType = "Project"
            $item.HierarchyLevel = 1
            $item.DisplaySortKey = Get-DisplaySortKey -level 1 -itemType "Project"
            $item.Category1Name = $matches[1].Trim()
            $currentCategoryNames.L1 = $item.Category1Name
            $currentCategoryNames.L2 = ""; $currentCategoryNames.L3 = ""; $currentCategoryNames.L4 = ""
            
            if ($nextLine -match "^\s*$" -and $afterNextLine -match "^%%\s*(.*)") {
                # $matches[1] は $afterNextLine のマッチ結果のキャプチャグループ1 (%% の後の文字列)
                $afterNextLine -match "^%%\s*(.*)" | Out-Null # これがないと $matches が更新されない
                $attributeString = $matches[1].Trim() 
                $attributesObject = ConvertTo-AttributeObject -AttributeString $attributeString # $attributesObject は PSCustomObject

                # Set-ItemAttributes の代わりに直接コピー
                if ($null -ne $attributesObject) {
                    foreach ($property in $attributesObject.PSObject.Properties) {
                        $propName = $property.Name
                        $propValue = $property.Value
                        if ($item.PSObject.Properties.Name -contains $propName) {
                            $item.$propName = $propValue
                        }
                    }
                }

                $i = $i + 2 
            }
            Write-Host "MainLoop: Item (Before Add to wbsItems)"
            $item.PSObject.Properties | ForEach-Object { Write-Host "  $($_.Name) = '$($_.Value)'" }
            $wbsItems.Add($item) # $item がリストに追加される
        }
        elseif ($currentLine -match "^##\s+(.*)") { # H2 (大分類)
            $item.ItemType = "Category1" # CSV列名と合わせるため Type は Cat1, Cat2, Cat3
            $item.HierarchyLevel = 2
            $item.DisplaySortKey = Get-DisplaySortKey -level 2 -itemType "Category1"
            $item.Category2Name = $matches[1].Trim() # 大分類名
            $currentCategoryNames.L2 = $item.Category2Name
            $currentCategoryNames.L3 = ""; $currentCategoryNames.L4 = ""
            $item.Category1Name = $currentCategoryNames.L1

            if ($nextLine -match "^\s*$" -and $afterNextLine -match "^%%\s*(.*)") {
                # $matches[1] は $afterNextLine のマッチ結果のキャプチャグループ1 (%% の後の文字列)
                $afterNextLine -match "^%%\s*(.*)" | Out-Null # これがないと $matches が更新されない
                $attributeString = $matches[1].Trim() 
                $attributesObject = ConvertTo-AttributeObject -AttributeString $attributeString # $attributesObject は PSCustomObject

                # Set-ItemAttributes の代わりに直接コピー
                if ($null -ne $attributesObject) {
                    foreach ($property in $attributesObject.PSObject.Properties) {
                        $propName = $property.Name
                        $propValue = $property.Value
                        if ($item.PSObject.Properties.Name -contains $propName) {
                            $item.$propName = $propValue
                        }
                    }
                }

                $i = $i + 2
            }
            Write-Host "MainLoop: Item (Before Add to wbsItems)"
            $item.PSObject.Properties | ForEach-Object { Write-Host "  $($_.Name) = '$($_.Value)'" }
            $wbsItems.Add($item) # $item がリストに追加される
        }
        elseif ($currentLine -match "^###\s+(.*)") { # H3 (中分類)
            $item.ItemType = "Category2"
            $item.HierarchyLevel = 3
            $item.DisplaySortKey = Get-DisplaySortKey -level 3 -itemType "Category2"
            $item.Category3Name = $matches[1].Trim() # 中分類名
            $currentCategoryNames.L3 = $item.Category3Name
            $currentCategoryNames.L4 = ""
            $item.Category1Name = $currentCategoryNames.L1
            $item.Category2Name = $currentCategoryNames.L2

           if ($nextLine -match "^\s*$" -and $afterNextLine -match "^%%\s*(.*)") {
                # $matches[1] は $afterNextLine のマッチ結果のキャプチャグループ1 (%% の後の文字列)
                $afterNextLine -match "^%%\s*(.*)" | Out-Null # これがないと $matches が更新されない
                $attributeString = $matches[1].Trim() 
                $attributesObject = ConvertTo-AttributeObject -AttributeString $attributeString # $attributesObject は PSCustomObject

                # Set-ItemAttributes の代わりに直接コピー
                if ($null -ne $attributesObject) {
                    foreach ($property in $attributesObject.PSObject.Properties) {
                        $propName = $property.Name
                        $propValue = $property.Value
                        if ($item.PSObject.Properties.Name -contains $propName) {
                            $item.$propName = $propValue
                        }
                    }
                }

                $i = $i + 2
            }
            Write-Host "MainLoop: Item (Before Add to wbsItems)"
            $item.PSObject.Properties | ForEach-Object { Write-Host "  $($_.Name) = '$($_.Value)'" }
            $wbsItems.Add($item) # $item がリストに追加される
        }
        elseif ($currentLine -match "^####\s+(.*)") { # H4 (小分類)
            $item.ItemType = "Category3"
            $item.HierarchyLevel = 4
            $item.DisplaySortKey = Get-DisplaySortKey -level 4 -itemType "Category3"
            $item.Category4Name = $matches[1].Trim() # 小分類名
            $currentCategoryNames.L4 = $item.Category4Name
            $item.Category1Name = $currentCategoryNames.L1
            $item.Category2Name = $currentCategoryNames.L2
            $item.Category3Name = $currentCategoryNames.L3

            if ($nextLine -match "^\s*$" -and $afterNextLine -match "^%%\s*(.*)") {
                # $matches[1] は $afterNextLine のマッチ結果のキャプチャグループ1 (%% の後の文字列)
                $afterNextLine -match "^%%\s*(.*)" | Out-Null # これがないと $matches が更新されない
                $attributeString = $matches[1].Trim() 
                $attributesObject = ConvertTo-AttributeObject -AttributeString $attributeString # $attributesObject は PSCustomObject

                # Set-ItemAttributes の代わりに直接コピー
                if ($null -ne $attributesObject) {
                    foreach ($property in $attributesObject.PSObject.Properties) {
                        $propName = $property.Name
                        $propValue = $property.Value
                        if ($item.PSObject.Properties.Name -contains $propName) {
                            $item.$propName = $propValue
                        }
                    }
                }

                $i = $i + 2
            }
            Write-Host "MainLoop: Item (Before Add to wbsItems)"
            $item.PSObject.Properties | ForEach-Object { Write-Host "  $($_.Name) = '$($_.Value)'" }
            $wbsItems.Add($item) # $item がリストに追加される
        }
        elseif ($currentLine -match "^(?:-|\*)\s+(.*?)(?:\s+<!--\s*(.*?)\s*-->)?$") { # Task item
            $item.ItemType = "Task"
            $item.HierarchyLevel = 5 
            $item.TaskName = $matches[1].Trim() # タスク名
            $item.DisplaySortKey = Get-DisplaySortKey -level 5 -itemType "Task"

            $item.Category1Name = $currentCategoryNames.L1
            $item.Category2Name = $currentCategoryNames.L2
            $item.Category3Name = $currentCategoryNames.L3
            $item.Category4Name = $currentCategoryNames.L4
            
            $htmlCommentAttributes = $matches[2] 
            if (-not [string]::IsNullOrWhiteSpace($htmlCommentAttributes)) {
                $attributesObject = ConvertTo-AttributeObject -AttributeString $htmlCommentAttributes # attributesObject に変更
                # Set-ItemAttributes の代わりに直接コピー
                if ($null -ne $attributesObject) {
                    foreach ($property in $attributesObject.PSObject.Properties) {
                        $propName = $property.Name
                        $propValue = $property.Value
                        if ($item.PSObject.Properties.Name -contains $propName) {
                            $item.$propName = $propValue
                        }
                    }
                }
            }
            $wbsItems.Add($item)
        }
    }
}

end {
    # CSV出力処理、最終メッセージ表示
    # --- CSV出力 ---
    $csvOutput = $wbsItems | Select-Object -Property @(
        @{Name="タスクID"; Expression={$_.DisplaySortKey}}
        @{Name="大分類"; Expression={ if ($_.HierarchyLevel -eq 2) { $_.Category2Name } else { "" } }}
        @{Name="中分類"; Expression={ if ($_.HierarchyLevel -eq 3) { $_.Category3Name } else { "" } }}
        @{Name="小分類"; Expression={ if ($_.HierarchyLevel -eq 4) { $_.Category4Name } else { "" } }}
        @{Name="タスク名称"; Expression={
            if ($_.HierarchyLevel -eq 1) { $_.Category1Name } # プロジェクト名
            elseif ($_.HierarchyLevel -eq 2) { "" } # 大分類名は専用列
            elseif ($_.HierarchyLevel -eq 3) { "" } # 中分類名は専用列
            elseif ($_.HierarchyLevel -eq 4) { "" } # 小分類名は専用列
            elseif ($_.HierarchyLevel -eq 5) { $_.TaskName }   # タスク名
            else { $_.TaskName } # フォールバック
        }}
        @{Name="担当組織"; Expression={$_.Organization}}
        @{Name="担当者"; Expression={$_.Assignee}}
        @{Name="終了日"; Expression={$_.EndDate}}
        @{Name="日数"; Expression={$_.Duration}}
        @{Name="進捗率"; Expression={$_.Progress}}
        @{Name="開始日実績"; Expression={$_.ActualStartDate}}
        @{Name="ユーザー記述ID"; Expression={$_.UserDefinedId}}
        @{Name="依存関係種別"; Expression={$_.DependencyType}}
        @{Name="先行タスクユーザー記述ID"; Expression={$_.PredecessorUserDefinedId}}
        @{Name="コメント"; Expression={$_.ItemComment}}
        @{Name="アイテム種別(デバッグ用)"; Expression={$_.ItemType}} 
    )

    # BOMなしUTF-8で出力
    $csvOutput | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "WBS data exported to: $OutputCsvPath"
    Write-Verbose "Finished script Convert-SimpleMdWbsToCsv.ps1"
}
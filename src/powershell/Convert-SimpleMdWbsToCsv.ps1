<#
.SYNOPSIS
    Converts a simple-md-wbs file to a CSV file.
.DESCRIPTION
    This script parses a simple-md-wbs file and outputs a CSV file.
#>
[CmdletBinding()]

param ( # 含まれる要素は","で区切る
    [Parameter(Mandatory=$true, HelpMessage="入力するsimple-md-wbsファイルのパス")]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    [string]$InputFilePath,

    [Parameter(Mandatory=$false, HelpMessage="出力するCSVファイルのパス")]
    [string]$OutputCsvPath = ".\wbs_output.csv" # デフォルト値をより一般的に
)

# paramブロックとbeginブロックの間には、コメント行、空行以外をいれることはできない。

begin {
    # 初期化処理
    $ErrorActionPreference = "Stop" # スクリプト全体のエラー処理方法を設定
    Write-Verbose "Starting script Convert-SimpleMdWbsToCsv.ps1"

    # --- モジュールのインポート ---
    # Get-DisplaySortKey や ConvertTo-AttributeObject 関数が含まれるモジュールを読み込む
    try {
        # スクリプト自身の場所を基準にモジュールへのパスを構築
        $modulePath = Join-Path $PSScriptRoot "Modules\MyCommonFunctions\MyCommonFunctions.psd1"
        Import-Module -Name $modulePath -Force
        Write-Verbose "Successfully imported module: $modulePath"
    } catch {
        Write-Error "Failed to import MyCommonFunctions module: $($_.Exception.Message)"
        Write-Error "Please ensure 'MyCommonFunctions.psd1' and its dependent files are located at '$modulePath'."
        Write-Error "Script location ($PSScriptRoot): $PSScriptRoot"
        exit 1
    }
    # --- モジュールのインポートここまで ---

    # --- グローバル変数の初期化 ---
    $script:wbsItems = [System.Collections.Generic.List[PSCustomObject]]::new() # スクリプトスコープで初期化
    $script:currentCategoryNames = @{ L1 = ""; L2 = ""; L3 = ""; L4 = "" } # スクリプトスコープで初期化

    # モジュール内のカウンターをスクリプト実行開始時にリセット
    Reset-WbsCounters
    Write-Verbose "WBS counters have been reset at the beginning of the script."
    # --- グローバル変数の初期化ここまで ---
} process {
    # ファイル読み込み、行ごとのパース処理
    try {
        # ファイルを読み込む
        $lines = Get-Content -Path $InputFilePath -ErrorAction Stop
        Write-Verbose "Successfully read file: $InputFilePath" # ログ出力
    } catch {
        Write-Error "Failed to read file: $($_.Exception.Message)"
        exit 1
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $currentLine = $lines[$i]
        $nextLine = if (($i + 1) -lt $lines.Count) { $lines[$i+1] } else { $null }
        $afterNextLine = if (($i + 2) -lt $lines.Count) { $lines[$i+2] } else { $null }

        # アクション1.1: $item オブジェクト定義の修正
        $item = [PSCustomObject]@{
            # --- 内部処理用の基本プロパティ ---
            DisplaySortKey = ""
            Category1Name = "" # プロジェクト名 (H1)
            Category2Name = "" # 大分類 (H2)
            Category3Name = "" # 中分類 (H3)
            Category4Name = "" # 小分類 (H4)
            TaskName = ""      # タスク名
            ItemType = "Unknown"
            HierarchyLevel = 0

            # --- simple-md-wbs 仕様書の13属性 (ConvertTo-AttributeObject からコピーされる) ---
            UserDefinedId            = "" # 属性1
            StartDateInput           = "" # 属性2
            EndDateInput             = "" # 属性3
            DurationInput            = "" # 属性4
            DependencyType           = "" # 属性5 「関連タスク種別」のこと
            PredecessorUserDefinedId = "" # 属性6 「関連タスクID」のこと
            ActualStartDate          = "" # 属性7
            ActualEndDate            = "" # 属性8
            Progress                 = "" # 属性9
            Assignee                 = "" # 属性10
            Organization             = "" # 属性11
            LastUpdatedDate          = "" # 属性12
            ItemComment              = "" # 属性13
        }

        if ($currentLine -match "^#\s+(.*?)(?:\s+<!--.*-->)?$") { # H1 (Project), HTMLコメントを除外
            $item.ItemType = "Project"
            $item.HierarchyLevel = 1
            $item.DisplaySortKey = Get-DecodedAndMappedAttribute -level 1 -itemType "Project"
            $item.Category1Name = $matches[1].Trim()
            $currentCategoryNames.L1 = $item.Category1Name
            $currentCategoryNames.L2 = ""; $currentCategoryNames.L3 = ""; $currentCategoryNames.L4 = ""

            if ($nextLine -match "^\s*$" -and $afterNextLine -match "^%%\s*(.*)") {
                # $matches[1] は $afterNextLine のマッチ結果のキャプチャグループ1 (%% の後の文字列)
                $afterNextLine -match "^%%\s*(.*)" | Out-Null # これがないと $matches が更新されない
                $fullAttributeLine = $matches[1].Trim()
                # 行末のHTML様コメントを除去 (より堅牢な正規表現を検討してもよい)
                $attributeString = ($fullAttributeLine -replace "\s*<!--.*?-->\s*$", "").Trim() # HTMLコメントを除去
                $attributesObject = ConvertTo-AttributeObject -AttributeString $attributeString
                Write-Verbose "For H1 '$($item.Category1Name)', AttributeString: '$attributeString'"
                # Set-ItemAttributes の代わりに直接コピー
                if ($null -ne $attributesObject) {
                    Write-Verbose "  Populating H1 item from attributesObject (UserDefinedId: '$($attributesObject.UserDefinedId)')"
                    foreach ($property in $attributesObject.PSObject.Properties) {
                        $propName = $property.Name
                        $propValue = $property.Value
                        if ($item.PSObject.Properties.Name -contains $propName) {
                            $item.$propName = $propValue
                            Write-Verbose "    Set `$item.$propName = '$($propValue)'"
                        }
                    }
                } else {
                    Write-Verbose "  ConvertTo-AttributeObject returned null for H1 attributes."
                }

                $i = $i + 2
            } # else の場合の属性処理（空のまま）は初期化で対応済み
            # Write-Host "DEBUG: MainLoop (H1): Item (Before Add to wbsItems): $($item | ConvertTo-Json -Compress -Depth 3)"
            $script:wbsItems.Add($item) # $item がリストに追加される
        }
        elseif ($currentLine -match "^##\s+(.*?)(?:\s+<!--.*-->)?$") { # H2 (大分類), HTMLコメントを除外
            $item.ItemType = "Category1" # CSV列名と合わせるため Type は Cat1, Cat2, Cat3
            $item.HierarchyLevel = 2
            $item.DisplaySortKey = Get-DecodedAndMappedAttribute -level 2 -itemType "Category1"
            $item.Category2Name = $matches[1].Trim()
            $currentCategoryNames.L2 = $item.Category2Name
            $currentCategoryNames.L3 = ""; $currentCategoryNames.L4 = ""
            $item.Category1Name = $currentCategoryNames.L1

            if ($nextLine -match "^\s*$" -and $afterNextLine -match "^%%\s*(.*)") {
                # $matches[1] は $afterNextLine のマッチ結果のキャプチャグループ1 (%% の後の文字列)
                $afterNextLine -match "^%%\s*(.*)" | Out-Null # これがないと $matches が更新されない
                $fullAttributeLine = $matches[1].Trim()
                # 行末のHTML様コメントを除去 (より堅牢な正規表現を検討してもよい)
                $attributeString = ($fullAttributeLine -replace "\s*<!--.*?-->\s*$", "").Trim() # HTMLコメントを除去
                $attributesObject = ConvertTo-AttributeObject -AttributeString $attributeString
                Write-Verbose "For H2 '$($item.Category2Name)', AttributeString: '$attributeString'"
                # Set-ItemAttributes の代わりに直接コピー
                if ($null -ne $attributesObject) {
                    Write-Verbose "  Populating H2 item from attributesObject (UserDefinedId: '$($attributesObject.UserDefinedId)')"
                    foreach ($property in $attributesObject.PSObject.Properties) {
                        $propName = $property.Name
                        $propValue = $property.Value
                        if ($item.PSObject.Properties.Name -contains $propName) {
                            $item.$propName = $propValue
                            Write-Verbose "    Set `$item.$propName = '$($propValue)'"
                        }
                    }
                } else {
                    Write-Verbose "  ConvertTo-AttributeObject returned null for H2 attributes."
                }

                $i = $i + 2
            } # else の場合の属性処理（空のまま）は初期化で対応済み
            # Write-Host "DEBUG: MainLoop (H2): Item (Before Add to wbsItems): $($item | ConvertTo-Json -Compress -Depth 3)"
            $script:wbsItems.Add($item) # $item がリストに追加される
        }
        elseif ($currentLine -match "^###\s+(.*?)(?:\s+<!--.*-->)?$") { # H3 (中分類), HTMLコメントを除外
            $item.ItemType = "Category2"
            $item.HierarchyLevel = 3
            $item.DisplaySortKey = Get-DecodedAndMappedAttribute -level 3 -itemType "Category2"
            $item.Category3Name = $matches[1].Trim()
            $currentCategoryNames.L3 = $item.Category3Name
            $currentCategoryNames.L4 = ""
            $item.Category1Name = $currentCategoryNames.L1
            $item.Category2Name = $currentCategoryNames.L2

           if ($nextLine -match "^\s*$" -and $afterNextLine -match "^%%\s*(.*)") {
                # $matches[1] は $afterNextLine のマッチ結果のキャプチャグループ1 (%% の後の文字列)
                $afterNextLine -match "^%%\s*(.*)" | Out-Null # これがないと $matches が更新されない
                $fullAttributeLine = $matches[1].Trim()
                # 行末のHTML様コメントを除去 (より堅牢な正規表現を検討してもよい)
                $attributeString = ($fullAttributeLine -replace "\s*<!--.*?-->\s*$", "").Trim() # HTMLコメントを除去
                $attributesObject = ConvertTo-AttributeObject -AttributeString $attributeString
                Write-Verbose "For H3 '$($item.Category3Name)', AttributeString: '$attributeString'"
                # Set-ItemAttributes の代わりに直接コピー
                if ($null -ne $attributesObject) {
                    Write-Verbose "  Populating H3 item from attributesObject (UserDefinedId: '$($attributesObject.UserDefinedId)')"
                    foreach ($property in $attributesObject.PSObject.Properties) {
                        $propName = $property.Name
                        $propValue = $property.Value
                        if ($item.PSObject.Properties.Name -contains $propName) {
                            $item.$propName = $propValue
                            Write-Verbose "    Set `$item.$propName = '$($propValue)'"
                        }
                    }
                } else {
                    Write-Verbose "  ConvertTo-AttributeObject returned null for H3 attributes."
                }

                $i = $i + 2
            } # else の場合の属性処理（空のまま）は初期化で対応済み
            # Write-Host "DEBUG: MainLoop (H3): Item (Before Add to wbsItems): $($item | ConvertTo-Json -Compress -Depth 3)"
            $script:wbsItems.Add($item) # $item がリストに追加される
        }
        elseif ($currentLine -match "^####\s+(.*?)(?:\s+<!--.*-->)?$") { # H4 (小分類), HTMLコメントを除外
            $item.ItemType = "Category3"
            $item.HierarchyLevel = 4
            $item.DisplaySortKey = Get-DecodedAndMappedAttribute -level 4 -itemType "Category3"
            $item.Category4Name = $matches[1].Trim()
            $currentCategoryNames.L4 = $item.Category4Name
            $item.Category1Name = $currentCategoryNames.L1
            $item.Category2Name = $currentCategoryNames.L2
            $item.Category3Name = $currentCategoryNames.L3

            if ($nextLine -match "^\s*$" -and $afterNextLine -match "^%%\s*(.*)") {
                # $matches[1] は $afterNextLine のマッチ結果のキャプチャグループ1 (%% の後の文字列)
                $afterNextLine -match "^%%\s*(.*)" | Out-Null # これがないと $matches が更新されない
                $fullAttributeLine = $matches[1].Trim()
                # 行末のHTML様コメントを除去 (より堅牢な正規表現を検討してもよい)
                $attributeString = ($fullAttributeLine -replace "\s*<!--.*?-->\s*$", "").Trim() # HTMLコメントを除去
                $attributesObject = ConvertTo-AttributeObject -AttributeString $attributeString
                Write-Verbose "For H4 '$($item.Category4Name)', AttributeString: '$attributeString'"
                # Set-ItemAttributes の代わりに直接コピー
                if ($null -ne $attributesObject) {
                    Write-Verbose "  Populating H4 item from attributesObject (UserDefinedId: '$($attributesObject.UserDefinedId)')"
                    foreach ($property in $attributesObject.PSObject.Properties) {
                        $propName = $property.Name
                        $propValue = $property.Value
                        if ($item.PSObject.Properties.Name -contains $propName) {
                            $item.$propName = $propValue
                            Write-Verbose "    Set `$item.$propName = '$($propValue)'"
                        }
                    }
                } else {
                    Write-Verbose "  ConvertTo-AttributeObject returned null for H4 attributes."
                }

                $i = $i + 2
            } # else の場合の属性処理（空のまま）は初期化で対応済み
            # Write-Host "DEBUG: MainLoop (H4): Item (Before Add to wbsItems): $($item | ConvertTo-Json -Compress -Depth 3)"
            $script:wbsItems.Add($item) # $item がリストに追加される
        }
        elseif ($currentLine -match "^(?:-|\*)\s+(.*?)(?:\s+<!--\s*(.*?)\s*-->)?$") { # Task item
            $item.ItemType = "Task"
            $item.HierarchyLevel = 5
            $item.TaskName = $matches[1].Trim() # タスク名
            $item.DisplaySortKey = Get-DecodedAndMappedAttribute -level 5 -itemType "Task"

            $item.Category1Name = $currentCategoryNames.L1
            $item.Category2Name = $currentCategoryNames.L2
            $item.Category3Name = $currentCategoryNames.L3
            $item.Category4Name = $currentCategoryNames.L4

            $htmlCommentAttributes = $matches[2]
            if (-not [string]::IsNullOrWhiteSpace($htmlCommentAttributes)) {
                $attributesObject = ConvertTo-AttributeObject -AttributeString $htmlCommentAttributes # attributesObject に変更
                Write-Verbose "For Task '$($item.TaskName)', AttributeString from HTML comment: '$htmlCommentAttributes'"
                # Set-ItemAttributes の代わりに直接コピー
                if ($null -ne $attributesObject) {
                    Write-Verbose "  Populating Task item from attributesObject (UserDefinedId: '$($attributesObject.UserDefinedId)')"
                    foreach ($property in $attributesObject.PSObject.Properties) {
                        $propName = $property.Name
                        $propValue = $property.Value
                        if ($item.PSObject.Properties.Name -contains $propName) {
                            $item.$propName = $propValue
                            Write-Verbose "    Set `$item.$propName = '$($propValue)'"
                        }
                    }
                } else {
                    Write-Verbose "  ConvertTo-AttributeObject returned null for Task attributes."
                }
            }
            $script:wbsItems.Add($item)
        }
    }
}

end {
    if ($script:wbsItems.Count -eq 0) {
        Write-Warning "No WBS items were processed. The output CSV file will not be generated."
        return
    }

    # アクション2.1: 依存関係解決機能の実装
    # --- 依存関係解決 ---
    Write-Verbose "Resolving dependencies..."
    foreach ($item in $script:wbsItems) { # スクリプトスコープのリストを参照
        if (-not [string]::IsNullOrWhiteSpace($item.PredecessorUserDefinedId)) {
            # $wbsItemsの中から、UserDefinedIdが$item.PredecessorUserDefinedIdと一致する最初のアイテムを探す
            $predecessor = $script:wbsItems | Where-Object { $_.UserDefinedId -eq $item.PredecessorUserDefinedId } | Select-Object -First 1

            if ($predecessor) {
                # 見つかった先行タスクの情報を現在のアイテムに追加
                $item | Add-Member -MemberType NoteProperty -Name "ResolvedPredecessorId" -Value $predecessor.DisplaySortKey
                $predecessorName = if (-not [string]::IsNullOrWhiteSpace($predecessor.TaskName)) { $predecessor.TaskName } else { ($predecessor.Category4Name, $predecessor.Category3Name, $predecessor.Category2Name, $predecessor.Category1Name | Where-Object {$_ -ne ""} | Select-Object -First 1) }
                $item | Add-Member -MemberType NoteProperty -Name "ResolvedPredecessorName" -Value $predecessorName
            } else {
                Write-Warning "Predecessor task with UserDefinedId '$($item.PredecessorUserDefinedId)' not found for item '$($item.UserDefinedId)' (TaskName: $($item.TaskName))."
                $item | Add-Member -MemberType NoteProperty -Name "ResolvedPredecessorId" -Value ""
                $item | Add-Member -MemberType NoteProperty -Name "ResolvedPredecessorName" -Value ""
            }
        } else {
            # PredecessorUserDefinedId がない場合もプロパティを追加しておくことで、Select-Object でエラーにならないようにする
            $item | Add-Member -MemberType NoteProperty -Name "ResolvedPredecessorId" -Value "" -ErrorAction SilentlyContinue
            $item | Add-Member -MemberType NoteProperty -Name "ResolvedPredecessorName" -Value "" -ErrorAction SilentlyContinue
        }
    }


    # CSV出力処理、最終メッセージ表示
    # アクション1.4: CSV出力 (Select-Object) の修正
    $csvOutput = $script:wbsItems | Select-Object -Property @(
        # @{Name="タスクID"; Expression={$_.DisplaySortKey}} # CSVヘッダーの1列目
        @{Name="タスクID"; Expression={
            # 仕様書3.0で定義された「表示用タスクID」を生成
            $sortId = $_.DisplaySortKey
            $parts = $sortId.Split('.') # 変数名を $id から $sortId に修正
            $outputParts = @()
            if ($_.HierarchyLevel -ge 2) { $outputParts += [int]$parts[0] } # 大分類
            if ($_.HierarchyLevel -ge 3) { $outputParts += [int]$parts[1] } # 中分類
            if ($_.HierarchyLevel -ge 4) { $outputParts += [int]$parts[2] } # 小分類
            if ($_.HierarchyLevel -ge 5) { $outputParts += [int]$parts[3] } # タスク
            if ($outputParts.Count -eq 0) { "0" } else { $outputParts -join '.' }
        }}
        @{Name="番号"; Expression={$_.DisplaySortKey}}
        @{Name="大分類"; Expression={ if ($_.HierarchyLevel -eq 2) { $_.Category2Name } else { "" } }}
        @{Name="中分類"; Expression={ if ($_.HierarchyLevel -eq 3) { $_.Category3Name } else { "" } }}
        @{Name="小分類"; Expression={ if ($_.HierarchyLevel -eq 4) { $_.Category4Name } else { "" } }}
        @{Name="タスクアイテム"; Expression={
            if ($_.HierarchyLevel -eq 1) { $_.Category1Name }
            elseif ($_.HierarchyLevel -in 2,3,4) { "" }
            else { $_.TaskName }
        }}
        @{Name="関連種別"; Expression={$_.DependencyType}}
        @{Name="関連番号"; Expression={$_.ResolvedPredecessorId}}
        @{Name="関連タスクアイテム"; Expression={$_.ResolvedPredecessorName}}
        @{Name="関連有無"; Expression={""}} # Excel数式用
        @{Name="コメント"; Expression={$_.ItemComment}}
        @{Name="進捗日数"; Expression={""}} # Excel数式用
        @{Name="作業遅延"; Expression={""}} # Excel数式用
        @{Name="開始遅延"; Expression={""}} # Excel数式用
        @{Name="遅延日数"; Expression={""}} # Excel数式用
        @{Name="担当組織"; Expression={$_.Organization}}
        @{Name="担当者名"; Expression={$_.Assignee}}
        @{Name="フラグ"; Expression={""}} # Excelユーザー定義用
        @{Name="最終更新"; Expression={$_.LastUpdatedDate}}
        @{Name="開始入力"; Expression={$_.StartDateInput}}
        @{Name="終了入力"; Expression={$_.EndDateInput}}
        @{Name="日数入力"; Expression={$_.DurationInput}}
        @{Name="開始計画"; Expression={""}} # Excel数式用
        @{Name="終了計画"; Expression={""}} # Excel数式用
        @{Name="日数計画"; Expression={""}} # Excel数式用
        @{Name="進捗実績"; Expression={$_.Progress}}
        @{Name="開始実績"; Expression={$_.ActualStartDate}}
        @{Name="修了実績"; Expression={$_.ActualEndDate}}
        @{Name="_emptyColumn28_"; Expression={""}} # 28番目の空列 (一時的なユニーク名)
        @{Name="_emptyColumn29_"; Expression={""}} # 29番目の空列 (一時的なユニーク名)
        @{Name="開始入力は平日？"; Expression={""}} # Excel数式用
        @{Name="終了入力は平日？"; Expression={""}} # Excel数式用
        # --- 以下はデバッグ用。最終的なCSV仕様に含まれない場合は削除またはコメントアウト ---
        # @{Name="ユーザー記述ID_元"; Expression={$_.UserDefinedId}}
        # @{Name="アイテム種別_デバッグ用"; Expression={$_.ItemType}}
    )

    try {
        # 出力ディレクトリが存在しない場合は作成
        $outputDir = Split-Path -Path $OutputCsvPath -Parent
        if (-not (Test-Path -Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force -ErrorAction Stop | Out-Null
            Write-Verbose "Created output directory: $outputDir"
        }
        $csvOutput | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Host "WBS data exported to: $OutputCsvPath"
    } catch {
        Write-Error "Failed to export CSV file: $($_.Exception.Message)"
    }
    Write-Verbose "Finished script Convert-SimpleMdWbsToCsv.ps1"
}
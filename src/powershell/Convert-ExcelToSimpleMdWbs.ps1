<#
.SYNOPSIS
    Converts a WBS (Work Breakdown Structure) from a specified Excel file to a simple-md-wbs format Markdown file.

.DESCRIPTION
    This script reads a WBS from a designated sheet in an Excel workbook. It parses the hierarchical structure and task attributes based on the column definitions,
    and then generates a Markdown file following the simple-md-wbs syntax.

    This script uses COM to interact with Excel, so it requires Excel to be installed on the machine where the script is run.

.PARAMETER ExcelPath
    The absolute path to the source Excel file. This parameter is mandatory.

.PARAMETER OutputPath
    The absolute path for the generated .md output file. This parameter is mandatory.

.PARAMETER SheetName
    The name of the worksheet containing the WBS data. Defaults to "wbs".

.EXAMPLE
    PS C:> Convert-ExcelToSimpleMdWbs.ps1 -ExcelPath "C:\projects\my-project.xlsx" -OutputPath "C:\projects\wbs.md"

    This command reads the WBS from the "wbs" sheet in "my-project.xlsx" and creates a "wbs.md" file in the simple-md-wbs format.

.EXAMPLE
    PS C:> Convert-ExcelToSimpleMdWbs.ps1 -ExcelPath "C:\data\source.xlsx" -OutputPath "C:\output\report.md" -SheetName "ProjectPlan"

    This command reads the WBS from the "ProjectPlan" sheet in "source.xlsx" and saves the output to "report.md".
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The absolute path to the source Excel file.")]
    [string]$ExcelPath,

    [Parameter(Mandatory = $true, HelpMessage = "The absolute path for the generated .md output file.")]
    [string]$OutputPath
)

begin {
    # ----------------------------------------------------------------
    # 初期化処理 (Initialization)
    # ----------------------------------------------------------------
    Write-Verbose "Initialization started."

    # TODO: MyCommonFunctionsモジュールのインポートパスを解決し、インポートする
    # Import-Module -Name "Path\To\MyCommonFunctions.psd1"

    # Excel COMオブジェクトの準備
    try {
        Write-Verbose "Creating Excel COM object."
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false # バックグラウンドで実行
    }
    catch {
        Write-Error "Failed to create Excel COM object. Make sure Excel is installed."
        # スクリプトの実行を停止するために例外を再スローする
        throw
    }

    # Excelワークブックを開く
    try {
        Write-Verbose "Opening workbook: $ExcelPath"
        $workbook = $excel.Workbooks.Open($ExcelPath, $true) # ReadOnlyで開く
    }
    catch {
        Write-Error "Failed to open Excel workbook at path: $ExcelPath"
        # COMオブジェクトを解放して終了
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
        throw
    }

    # 対象シートを選択 (規約: 常に最初のシートを使用)
    try {
        Write-Verbose "Selecting the first worksheet."
        $worksheet = $workbook.Sheets.Item(1)
    }
    catch {
        Write-Error "Failed to select the first worksheet in the workbook."
        # COMオブジェクトを解放して終了
        $workbook.Close($false)
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
        throw
    }

    # simple-md-wbs のコンテンツを格納する変数
    $mdContent = ""
}

process {
    # ----------------------------------------------------------------
    # メイン処理 (Main Processing) - 最終修正ロジック
    # ----------------------------------------------------------------
    Write-Verbose "Main processing started."

    # --- 列名とプロパティ名のマッピング定義 ---
    $columnMap = @{
        "大分類"       = "CategoryH2";
        "中分類"       = "CategoryH3";
        "小分類"       = "CategoryH4";
        "タスクアイテム" = "TaskItem";
        "ユーザー記述ID" = "UserID";
        "開始入力"     = "StartDate";
        "終了入力"     = "EndDate";
        "日数入力"     = "Duration";
        "関連種別"     = "DepType";
        "関連番号"     = "DepID";
        "開始実績"     = "StartDateActual";
        "修了実績"     = "EndDateActual";
        "進捗実績"     = "Progress";
        "担当者名"     = "Assignee";
        "担当組織"     = "Org";
        "最終更新"     = "LastUpdate";
        "コメント"     = "Comment"
    }

    # --- ヘッダーを解析して列インデックスを取得 ---
    $headerRow = 4
    $dataStartRow = 5
    $columnIndexes = @{}
    $headerRange = $worksheet.Rows($headerRow)
    for ($col = 1; $col -le $worksheet.UsedRange.Columns.Count; $col++) {
        $headerText = $worksheet.Cells.Item($headerRow, $col).Text
        if (-not [string]::IsNullOrEmpty($headerText) -and $columnMap.ContainsKey($headerText)) {
            $propName = $columnMap[$headerText]
            Write-Verbose "Found column '$headerText' at index $col. Mapping to '$propName'."
            $columnIndexes[$propName] = $col
        }
    }

    if (-not $columnIndexes.ContainsKey("TaskItem")) {
        Write-Error "The required column 'タスクアイテム' was not found."
        throw
    }
    # --- ヘッダー解析ここまで ---

    # --- 全データ行を階層構造を維持して読み込む (ForEachループ) ---
    $script:allRowsData = [System.Collections.Generic.List[psobject]]::new()
    Write-Verbose "Reading data using ForEach loop over UsedRange.Rows."

    $currentCategoryH2 = ""
    $currentCategoryH3 = ""
    $currentCategoryH4 = ""
    $rowNum = 0

    foreach ($row in $worksheet.UsedRange.Rows) {
        $rowNum++
        if ($rowNum -lt $dataStartRow) { continue } # ヘッダー行をスキップ

        # 1. 常にカテゴリ階層を更新する
        $h2Value = $row.Cells(1, $columnIndexes["CategoryH2"]).Text
        $h3Value = $row.Cells(1, $columnIndexes["CategoryH3"]).Text
        $h4Value = $row.Cells(1, $columnIndexes["CategoryH4"]).Text

        if (-not [string]::IsNullOrWhiteSpace($h2Value)) {
            $currentCategoryH2 = $h2Value
            $currentCategoryH3 = ""
            $currentCategoryH4 = ""
        }
        if (-not [string]::IsNullOrWhiteSpace($h3Value)) {
            $currentCategoryH3 = $h3Value
            $currentCategoryH4 = ""
        }
        if (-not [string]::IsNullOrWhiteSpace($h4Value)) {
            $currentCategoryH4 = $h4Value
        }

        # 2. タスクアイテムが存在する場合にのみ、オブジェクトを作成してリストに追加する
        $taskItemCellText = $row.Cells(1, $columnIndexes["TaskItem"]).Text
        if (-not [string]::IsNullOrWhiteSpace($taskItemCellText)) {
            $rowData = [PSCustomObject]@{}

            # 現在のカテゴリ情報をオブジェクトに追加
            $rowData | Add-Member -MemberType NoteProperty -Name "CategoryH2" -Value $currentCategoryH2
            $rowData | Add-Member -MemberType NoteProperty -Name "CategoryH3" -Value $currentCategoryH3
            $rowData | Add-Member -MemberType NoteProperty -Name "CategoryH4" -Value $currentCategoryH4

            # その他のプロパティを読み込む
            foreach ($propName in $columnIndexes.Keys) {
                if ($propName -in @("CategoryH2", "CategoryH3", "CategoryH4")) {
                    continue
                }
                $colIndex = $columnIndexes[$propName]
                $cellValue = $row.Cells(1, $colIndex).Text
                $rowData | Add-Member -MemberType NoteProperty -Name $propName -Value $cellValue
            }
            $script:allRowsData.Add($rowData)
        }
    }
    Write-Verbose "Successfully read and structured $($script:allRowsData.Count) data rows."
    # --- データ読み込みここまで ---
}

end {
    # ----------------------------------------------------------------
    # コンテンツ生成と後処理 (Final logic)
    # ----------------------------------------------------------------
    Write-Verbose "Generating simple-md-wbs content and finalizing."

    try {
        $lastCategoryH2 = ""
        $lastCategoryH3 = ""
        $lastCategoryH4 = ""

        # simple-md-wbs仕様で定義された13個の属性の順序
        $attributeOrder = @(
            'UserID', 'StartDate', 'EndDate', 'Duration', 'DepType', 'DepID',
            'StartDateActual', 'EndDateActual', 'Progress', 'Assignee', 'Org',
            'LastUpdate', 'Comment'
        )

        foreach ($row in $script:allRowsData) {
            # --- ヘルパー関数を使わずに直接プロパティ値を取得 ---
            $CategoryH2 = ($row.PSObject.Properties | Where-Object { $_.Name -eq 'CategoryH2' }).Value
            $CategoryH3 = ($row.PSObject.Properties | Where-Object { $_.Name -eq 'CategoryH3' }).Value
            $CategoryH4 = ($row.PSObject.Properties | Where-Object { $_.Name -eq 'CategoryH4' }).Value
            $TaskItem = ($row.PSObject.Properties | Where-Object { $_.Name -eq 'TaskItem' }).Value

            # --- 見出しの出力判定 ---
            if (-not [string]::IsNullOrWhiteSpace($CategoryH2) -and $CategoryH2 -ne $lastCategoryH2) {
                $mdContent += "`n## $CategoryH2`n`n"
                $lastCategoryH2 = $CategoryH2
                $lastCategoryH3 = ""
                $lastCategoryH4 = ""
            }
            if (-not [string]::IsNullOrWhiteSpace($CategoryH3) -and $CategoryH3 -ne $lastCategoryH3) {
                $mdContent += "### $CategoryH3`n`n"
                $lastCategoryH3 = $CategoryH3
                $lastCategoryH4 = ""
            }
            if (-not [string]::IsNullOrWhiteSpace($CategoryH4) -and $CategoryH4 -ne $lastCategoryH4) {
                $mdContent += "#### $CategoryH4`n`n"
                $lastCategoryH4 = $CategoryH4
            }

            # --- タスクの出力処理 ---
            if (-not [string]::IsNullOrWhiteSpace($TaskItem)) {
                $attributeValues = foreach ($propName in $attributeOrder) {
                    $prop = $row.PSObject.Properties | Where-Object { $_.Name -eq $propName }
                    if ($prop) { $prop.Value } else { "" }
                }
                $attributesString = $attributeValues -join ','
                $mdContent += "- $TaskItem <!-- $attributesString -->`n"
            }
        }

        # --- ファイルへの書き込み ---
        Write-Verbose "Writing content to output file: $OutputPath"
        [System.IO.File]::WriteAllText($OutputPath, $mdContent, [System.Text.Encoding]::UTF8)
    }
    catch {
        Write-Error "An error occurred during content generation or file writing: $_"
        throw
    }
    finally {
        # --- COMオブジェクトの解放 ---
        Write-Verbose "Releasing COM objects."
        if ($worksheet -ne $null) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($worksheet) | Out-Null }
        if ($workbook -ne $null) { $workbook.Close($false); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) | Out-Null }
        if ($excel -ne $null) { $excel.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null }
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }

    Write-Verbose "Script finished successfully."
}
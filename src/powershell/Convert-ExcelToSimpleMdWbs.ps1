<#
.SYNOPSIS
    Converts a WBS (Work Breakdown Structure) from a specified Excel file to a simple-md-wbs format Markdown file.

.DESCRIPTION
    This script reads a WBS from a designated sheet in an Excel workbook. It parses the hierarchical structure and task attributes based on the column definitions,
    and then generates a Markdown file following the simple-md-wbs syntax.

    The script uses COM to interact with Excel, so it requires Excel to be installed on the machine where the script is run.

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
    [string]$OutputPath,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the worksheet containing the WBS data.")]
    [string]$SheetName = "wbs"
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

    # 対象シートを選択
    try {
        Write-Verbose "Selecting worksheet: $SheetName"
        $worksheet = $workbook.Sheets.Item($SheetName)
    }
    catch {
        Write-Error "Failed to find worksheet with name: $SheetName"
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
    # メイン処理 (Main Processing)
    # ----------------------------------------------------------------
    Write-Verbose "Main processing started."

    # --- 列名とプロパティ名のマッピング定義 ---
    $columnMap = @{
        "大分類"       = "CategoryH2";
        "中分類"       = "CategoryH3";
        "小分類"       = "CategoryH4";
        "タスクアイテム" = "TaskItem";
        "ユーザー記述ID" = "UserID";
        "担当者名"     = "Assignee";
        "開始入力"     = "StartDate";
        "終了入力"     = "EndDate";
        "日数入力"     = "Duration";
        "進捗実��"     = "Progress"
    }

    # --- ヘッダーを解析して列インデックスを取得 ---
    $headerRow = 4
    $dataStartRow = 5
    $columnIndexes = @{}

    $headerRange = $worksheet.Rows($headerRow)
    for ($col = 1; $col -le $worksheet.UsedRange.Columns.Count; $col++) {
        $headerText = $worksheet.Cells.Item($headerRow, $col).Text
        if ($columnMap.ContainsKey($headerText)) {
            $propName = $columnMap[$headerText]
            Write-Verbose "Found column '$headerText' at index $col. Mapping to '$propName'."
            $columnIndexes[$propName] = $col
        }
    }

    # 必須列の存在チェック
    if (-not $columnIndexes.ContainsKey("TaskItem")) {
        Write-Error "The required column 'タスクアイテム' was not found."
        throw
    }
    # --- ヘッダー解析ここまで ---

    # --- 全データ行をメモリ上のオブジェクトリストに読み込む ---
    $script:allRowsData = [System.Collections.Generic.List[psobject]]::new()
    $lastRow = $worksheet.UsedRange.Rows.Count
    Write-Verbose "Reading data from row $dataStartRow to $lastRow."

    for ($rowNum = $dataStartRow; $rowNum -le $lastRow; $rowNum++) {
        $taskItemCellText = $worksheet.Cells.Item($rowNum, $columnIndexes["TaskItem"]).Text
        if ([string]::IsNullOrWhiteSpace($taskItemCellText)) {
            continue
        }

        $rowData = [PSCustomObject]@{
            RowNumber    = $rowNum
            OutlineLevel = $worksheet.Rows($rowNum).OutlineLevel
            Children     = [System.Collections.Generic.List[psobject]]::new()
        }

        foreach ($propName in $columnIndexes.Keys) {
            $colIndex = $columnIndexes[$propName]
            $cellValue = $worksheet.Cells.Item($rowNum, $colIndex).Text
            $rowData | Add-Member -MemberType NoteProperty -Name $propName -Value $cellValue
        }
        $script:allRowsData.Add($rowData)
    }
    Write-Verbose "Successfully read $($script:allRowsData.Count) data rows."
    # --- データ読み込みここまで ---
}

end {
    # ----------------------------------------------------------------
    # 後処理 (Finalization)
    # ----------------------------------------------------------------
    Write-Verbose "Finalization started."

    # --- データ内容に基づいて階層構造を構築し、Markdownを生成 ---
    $mdContent = "# $($worksheet.Name)" + "`n"
    $lastH2 = ""
    $lastH3 = ""
    $lastH4 = ""

    # Excelの表示順に処理
    foreach ($row in $script:allRowsData) {
        # --- 階層（見出し）の処理 ---
        # Excelの各行にはその行が属する分類がすべて記載されている前提で、
        # 直前の行と比較して分類が変更された場合にのみ見出しを出力する。
        
        # 大分類のチェック
        $currentH2 = $row.CategoryH2
        if (-not [string]::IsNullOrWhiteSpace($currentH2) -and $currentH2 -ne $lastH2) {
            $mdContent += "`n## $currentH2`n`n"
            $lastH2 = $currentH2
            $lastH3 = "" # 上位カテゴリが変わったら下位はリセット
            $lastH4 = ""
        }

        # 中分類��チェック
        $currentH3 = $row.CategoryH3
        if (-not [string]::IsNullOrWhiteSpace($currentH3) -and $currentH3 -ne $lastH3) {
            $mdContent += "### $currentH3`n`n"
            $lastH3 = $currentH3
            $lastH4 = ""
        }

        # 小分類のチェック
        $currentH4 = $row.CategoryH4
        if (-not [string]::IsNullOrWhiteSpace($currentH4) -and $currentH4 -ne $lastH4) {
            $mdContent += "#### $currentH4`n`n"
            $lastH4 = $currentH4
        }

        # --- タスク行の処理 ---
        # すべての行をタスクとして出力する
            
        # --- 属性文字列の生成 ---
        $attributePairs = [System.Collections.Generic.List[string]]::new()
        # 属性の定義を統一
        $attributeMap = @{
            "ユーザー記述ID" = "UserID";
            "開始日（入力）"   = "StartDate";
            "終了日（入力）"   = "EndDate";
            "日数（入力）"     = "Duration";
            "進捗率"         = "Progress";
            "担当者"         = "Assignee"
        }
        
        foreach ($attrName in $attributeMap.Keys) {
            $propName = $attributeMap[$attrName]
            $property = $row.PSObject.Properties[$propName]
            if ($null -ne $property) {
                $value = $property.Value
                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    $attributePairs.Add("$attrName=$value")
                }
            }
        }
        $attributes = ""
        if ($attributePairs.Count -gt 0) {
            $attributes = " <!-- $($attributePairs -join ', ') -->"
        }
        # --- 属性文字列の生成ここまで ---

        $mdContent += "- " + $row.TaskItem + $attributes + "`n"
        
    }
    # --- 生成実行ここまで ---

    # 生成したMarkdownコンテンツをファイルに出力
    try {
        Write-Verbose "Writing output to file: $OutputPath"
        Set-Content -Path $OutputPath -Value $mdContent -Encoding UTF8
        Write-Host "Successfully converted Excel WBS to simple-md-wbs: $OutputPath"
    }
    catch {
        Write-Error "Failed to write output file at: $OutputPath"
    }
    finally {
        # Excel COMオブジェクトを解放
        if ($workbook) { $workbook.Close($false) }
        if ($excel) { $excel.Quit() }
        if ($excel) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null }
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
    }
}


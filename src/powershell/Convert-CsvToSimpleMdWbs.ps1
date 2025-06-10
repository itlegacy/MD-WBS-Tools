# Convert-CsvToSimpleMdWbs.ps1
<#
.SYNOPSIS
    標準順序のCSVファイルをsimple-md-wbs形式のMarkdownファイルに変換します。
.DESCRIPTION
    このスクリプトは、特定の列構成を持つCSVファイルを読み込み、
    階層構造を復元しながらsimple-md-wbs記法に基づいたMarkdownテキストを生成し、
    指定されたファイルに出力します。
.PARAMETER InputCsvPath
    入力する標準順序CSVファイルのパス。このファイルは存在し、読み取り可能である必要があります。
.PARAMETER OutputMdPath
    出力するsimple-md-wbs形式のMarkdownファイルのパス。
    指定しない場合、スクリプトと同じディレクトリに "output.md" として出力されます。
.EXAMPLE
    PS C:\> Convert-CsvToSimpleMdWbs.ps1 -InputCsvPath .\input.csv -OutputMdPath .\wbs.md -Verbose
    指定されたinput.csvを読み込み、wbs.mdとしてsimple-md-wbs形式で出力します。詳細なログも表示されます。
.NOTES
    Version: 0.1.0
    Author: Your Name / AI Assistant
    CSVの入力仕様については、docs/10_requirements_definition.yaml を参照してください。
    階層復元はCSVの「番号」列に依存します。
#>
[CmdletBinding()] # この行より前に何らかの意味のあるコードがあると、Unexpected attribute 'CmdletBinding'.となる：コーディング規則にいれる

param (
    [Parameter(Mandatory = $true, HelpMessage = "入力する標準順序CSVファイルのパス。ファイルが存在する必要があります。")]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) {
            throw "指定された入力CSVファイルが見つかりません: $_"
        }
        # TODO: CSVファイルが読み取り可能かどうかのチェックも追加検討
        return $true
    })]
    [string]$InputCsvPath,

    [Parameter(Mandatory = $false, HelpMessage = "出力するsimple-md-wbsファイルのパス。デフォルトはカレントディレクトリの'output.md'です。")]
    [string]$OutputMdPath = (Join-Path $PSScriptRoot "output.md") # デフォルトをスクリプトと同じディレクトリに
)

begin {
    # 初期化処理 <# .SYNOPSIS 標準順序のCSVファイルをsimple-md-wbs形式のMarkdownファイルに変換します。 #> # [CmdletBinding] の前に以下があると失敗するのこの位置に
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop" # スクリプト全体のエラー処理方法を設定

    Write-Verbose "Starting script: $($MyInvocation.MyCommand.Name)"
    Write-Verbose "Input CSV Path: $InputCsvPath"
    Write-Verbose "Output Markdown Path: $OutputMdPath"

    # 必要なモジュールのインポート (もしあれば)
    try {
        # $PSScriptRoot からの相対パスでモジュールマニフェストのフルパスを構築
        $commonModulePath = Join-Path $PSScriptRoot "Modules/MyCommonFunctions/MyCommonFunctions.psd1"
        Import-Module -Name $commonModulePath -Force -ErrorAction Stop
        Write-Verbose "Successfully imported MyCommonFunctions module from: $commonModulePath"
    }
    catch {
        Write-Error "必要なモジュール MyCommonFunctions のインポートに失敗しました: $($_.Exception.Message)"
        exit 1
    }

    # 結果を格納する変数などの初期化
    $wbsItemsFromCsv = @()
    $markdownOutputLines = [System.Collections.Generic.List[string]]::new()

    Write-Verbose "Initialization complete."
}

# <----- ここからコピー -----
process {
    try {
        # --- ステップ1 & 2: データ前処理とカスタムソート（完成済み）---
        $lines = Get-Content -Path $InputCsvPath -Encoding UTF8
        $headerLine = $lines[4]; if ($headerLine.StartsWith([char]0xFEFF)) { $headerLine = $headerLine.Substring(1) }
        $headers = $headerLine.Split(',') | ForEach-Object { $_.Trim().Replace('"', '') }
        $items = foreach ($line in $lines[5..($lines.Count - 1)]) {
            if ([string]::IsNullOrWhiteSpace($line) -or ($line -replace ',', '').Trim() -eq '') { continue }
            $values = $line.Split(','); $propHash = [ordered]@{}; for ($i = 0; $i -lt $headers.Length; $i++) { if (-not [string]::IsNullOrWhiteSpace($headers[$i])) { $propHash[$headers[$i]] = if ($i -lt $values.Length) { $values[$i].Trim().Replace('"', '') } else { "" } } }; [PSCustomObject]$propHash
        }
        $sortedItems = @($items | Where-Object { $_.PSObject.Properties['番号'] -and -not [string]::IsNullOrWhiteSpace($_.'番号') } | Sort-Object -Property @{ Expression = { ($_.PSObject.Properties['番号'].Value.Split('.') | ForEach-Object { if ($_ -eq 'z') { '_' } else { "{0:D3}" -f ([int]$_) } }) -join '.' } })
        
        # --- ステップ3: Markdown生成処理（最終完成版 Ver.1.2：可読性向上） ---
        $projectName = ($lines[0].Split(','))[4].Trim().Replace('"', '')
        $markdownOutputLines.Add("# $projectName")

        foreach ($item in $sortedItems) {
            $adapterObject = [PSCustomObject]@{ 'ユーザー記述ID'='';'開始入力'=if($item.'開始入力'){$item.'開始入力'}else{''};'終了入力'=if($item.'終了入力'){$item.'終了入力'}else{''};'日数入力'=if($item.'日数入力'){$item.'日数入力'}else{''};'関連種別'=if($item.'関連種別'){$item.'関連種別'}else{''};'先行タスクユーザー記述ID'=if($item.'関連番号'){$item.'関連番号'}else{''};'開始実績'=if($item.'開始実績'){$item.'開始実績'}else{''};'修了実績'=if($item.'修了実績'){$item.'修了実績'}else{''};'進捗実績'=if($item.'進捗実績'){$item.'進捗実績'}else{''};'担当者名'=if($item.'担当者名'){$item.'担当者名'}else{''};'担当組織'=if($item.'担当組織'){$item.'担当組織'}else{''};'最終更新'=if($item.'最終更新'){$item.'最終更新'}else{''};'コメント'=if($item.'コメント'){$item.'コメント'}else{''} }
            $attributeString = ConvertTo-SimpleMdWbsAttributeString -CsvRowItem $adapterObject
            $isAttributeEmpty = ($attributeString -replace '[,\s]', '').Length -eq 0

            # --- あなたのロジック + 可読性向上のための改行制御 ---
            if (-not [string]::IsNullOrWhiteSpace($item.'大分類')) {
                $markdownOutputLines.Add(""); $markdownOutputLines.Add("## $($item.'大分類')")
                if (-not $isAttributeEmpty) { $markdownOutputLines.Add("%% $attributeString") }
                $markdownOutputLines.Add("")
            } 
            elseif (-not [string]::IsNullOrWhiteSpace($item.'中分類')) {
                $markdownOutputLines.Add(""); $markdownOutputLines.Add("### $($item.'中分類')")
                if (-not $isAttributeEmpty) { $markdownOutputLines.Add("%% $attributeString") }
                $markdownOutputLines.Add("")
            } 
            elseif (-not [string]::IsNullOrWhiteSpace($item.'小分類')) {
                $markdownOutputLines.Add(""); $markdownOutputLines.Add("#### $($item.'小分類')")
                $markdownOutputLines.Add("")
                
                $taskLine = "- $($item.'小分類')"
                if (-not $isAttributeEmpty) { $taskLine += " <!-- $attributeString -->" }
                $markdownOutputLines.Add($taskLine)
            }
            elseif (-not [string]::IsNullOrWhiteSpace($item.'タスクアイテム')) {
                $taskLine = "- $($item.'タスクアイテム')"
                if (-not $isAttributeEmpty) { $taskLine += " <!-- $attributeString -->" }
                $markdownOutputLines.Add($taskLine)
            }
        }
    }
    catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
    }
}
# <----- ここまでコピー -----

end {
    Write-Verbose "Finalizing script and generating output file: $OutputMdPath"
    if ($markdownOutputLines.Count -gt 0) {
        try {
            # 出力ディレクトリが存在しない場合は作成
            $outputDirectory = Split-Path -Path $OutputMdPath -Parent
            if (-not (Test-Path $outputDirectory)) {
                Write-Verbose "Creating output directory: $outputDirectory"
                New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
            }

            Set-Content -Path $OutputMdPath -Value $markdownOutputLines -Encoding UTF8 -Force
            Write-Host "simple-md-wbs file has been successfully generated: $OutputMdPath"
        }
        catch {
            Write-Error "Markdownファイルの出力中にエラーが発生しました: $($_.Exception.Message)"
            Write-Error "スタックトレース: $($_.ScriptStackTrace)"
        }
    }
    else {
        Write-Warning "生成するMarkdownコンテンツがありません。ファイルは出力されませんでした。"
    }
    Write-Verbose "Script finished."
}

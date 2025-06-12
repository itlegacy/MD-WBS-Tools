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
# using module は、他のどのコードよりも先に、スクリプトの先頭に記述する必要があります
using module ".\Modules\MyCommonFunctions\MyCommonFunctions.psm1"

[CmdletBinding()]
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

    # Import-Module は不要になるため、begin ブロックから削除またはコメントアウトします
    # try { ... Import-Module ... } catch { ... } のブロックを削除
    Write-Verbose "Initialization complete. Module is loaded via 'using module'."


    # 結果を格納する変数などの初期化
    $wbsItemsFromCsv = @()
    $markdownOutputLines = [System.Collections.Generic.List[string]]::new()

    Write-Verbose "Initialization complete."
}

process {
    try {
        Write-Verbose "Reading and parsing CSV file: $InputCsvPath"
        $wbsItemsFromCsv = Import-Csv -Path $InputCsvPath -Encoding UTF8
        
        if ($null -eq $wbsItemsFromCsv -or $wbsItemsFromCsv.Count -eq 0) {
            Write-Warning "CSV file is empty or contains no data rows."
            return
        }

        Write-Verbose "Generating Markdown content based on the 'visual' rule..."

        $isFirstLine = $true
        foreach ($item in $wbsItemsFromCsv) {
            
            $attributeString = ConvertTo-SimpleMdWbsAttributeString -CsvRowItem $item
            $isAttributeEmpty = ($attributeString -replace '[,\s]', '').Length -eq 0

            if (-not [string]::IsNullOrEmpty($item.'大分類')) {
                # [要求3] 最初の行でなければ、見出しの前に空行を1つだけ挿入
                if (-not $isFirstLine) {
                    $markdownOutputLines.Add("")
                }
                $markdownOutputLines.Add("## $($item.'大分類')")
                if (-not $isAttributeEmpty) { $markdownOutputLines.Add("%% $attributeString") }
            } 
            elseif (-not [string]::IsNullOrEmpty($item.'中分類')) {
                # [要求3] 最初の行でなければ、見出しの前に空行を1つだけ挿入
                if (-not $isFirstLine) {
                    $markdownOutputLines.Add("")
                }
                $markdownOutputLines.Add("### $($item.'中分類')")
                if (-not $isAttributeEmpty) { $markdownOutputLines.Add("%% $attributeString") }
            } 
            elseif (-not [string]::IsNullOrEmpty($item.'小分類')) {
                # [要求3] 最初の行でなければ、見出しの前に空行を1つだけ挿入
                if (-not $isFirstLine) {
                    $markdownOutputLines.Add("")
                }
                $markdownOutputLines.Add("#### $($item.'小分類')")
                if (-not $isAttributeEmpty) { $markdownOutputLines.Add("%% $attributeString") }
            }
            elseif (-not [string]::IsNullOrEmpty($item.'タスクアイテム')) {
                if ($item.番号.EndsWith("00.00.00")) { # 番号が .00.00.00 で終わるならH1
                    # [要求3] 最初の行でなければ、見出しの前に空行を1つだけ挿入
                    if (-not $isFirstLine) {
                        $markdownOutputLines.Add("")
                    }
                    $markdownOutputLines.Add("# $($item.'タスクアイテム')")
                    if (-not $isAttributeEmpty) { $markdownOutputLines.Add("%% $attributeString") }
                } else { # 通常のタスク
                    # [要求1 & 2] インデントを削除し、属性をHTMLコメントで囲む
                    $taskLine = "- $($item.'タスクアイテム')"
                    if (-not $isAttributeEmpty) { $taskLine += " <!-- $attributeString -->" }
                    $markdownOutputLines.Add($taskLine)
                }
            }
            
            $isFirstLine = $false
        }
    }
    catch {
        Write-Error "An error occurred during main processing: $($_.Exception.Message)"
        Write-Verbose "ERROR: $($_.Exception.Message) at $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)"
    }
}

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

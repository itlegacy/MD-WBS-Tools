# テストケース1: 基本的な変換テスト
.\src\powershell\Convert-SimpleMdWbsToCsv.ps1 -InputFilePath ".\samples\mdwbs_examples\sample_project_A.md" -OutputCsvPath ".\test_outputs\mdwbs_to_csv\sample_project_A_output.csv" -Verbose

# テストケース2: 別のサンプルファイル (もしあれば)
# .\src\powershell\Convert-SimpleMdWbsToCsv.ps1 -InputFilePath ".\samples\mdwbs_examples\another_sample.md" -OutputCsvPath ".\test_outputs\mdwbs_to_csv\another_sample_output.csv" -Verbose
```*   `-Verbose` スイッチを付けることで、スクリプトの詳細な処理ログを確認できます。

---

**ステップ3: テスト用簡易スクリプトの作成 (オプションだが推奨)**

毎回コマンドを手で打つのは手間なので、複数のテストケースをまとめて実行したり、期待結果との比較を自動化したりするための簡単なテストランナースクリプトを作成すると便利です。これはPesterのような厳密なテストフレームワークである必要はありません。

**テストランナースクリプト例 (`Run-ConversionTests.ps1` などとして `tests/powershell/` に配置):**

```powershell
<#
.SYNOPSIS
    Runs integration tests for Convert-SimpleMdWbsToCsv.ps1.
.DESCRIPTION
    Executes Convert-SimpleMdWbsToCsv.ps1 with predefined sample files
    and checks if the output CSV is generated.
    More advanced checks (like comparing with an expected CSV) can be added later.
#>
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop" # スクリプト内でエラーがあれば停止

# リポジトリルートを基準にパスを構築
$repoRoot = (Get-Location).Path
if ($repoRoot -notmatch "MD-WBS-Tools$") { # カレントディレクトリがリポジトリルートでない場合の簡易的な調整
    $repoRoot = (Split-Path $PSScriptRoot -Parent) # tests/powershell から MD-WBS-Tools に上がる
    if ($repoRoot -notmatch "MD-WBS-Tools$") {
         $repoRoot = (Split-Path $repoRoot -Parent) # さらに MD-WBS-Tools に上がる (もし tests/powershell/subfolder のような場合)
    }
    if ($repoRoot -notmatch "MD-WBS-Tools$"){
        Write-Error "リポジトリのルートディレクトリを正しく特定できませんでした。スクリプトをリポジトリ内の適切な場所から実行してください。"
        exit 1
    }
}


$mainScriptPath = Join-Path $repoRoot "src\powershell\Convert-SimpleMdWbsToCsv.ps1"
$samplesDir = Join-Path $repoRoot "samples\mdwbs_examples"
$outputBaseDir = Join-Path $repoRoot "test_outputs\mdwbs_to_csv"

# 出力ディレクトリがなければ作成
if (-not (Test-Path $outputBaseDir)) {
    New-Item -ItemType Directory -Path $outputBaseDir -Force | Out-Null
}

# --- テストケース定義 ---
$testCases = @(
    @{
        Name = "ProjectA_BasicConversion"
        InputFile = Join-Path $samplesDir "sample_project_A.md"
        OutputFile = Join-Path $outputBaseDir "sample_project_A_output.csv"
        ExpectedToSucceed = $true # 期待通り成功するかどうか
    }
    # @{
    #     Name = "AnotherSample_Conversion"
    #     InputFile = Join-Path $samplesDir "another_sample.md"
    #     OutputFile = Join-Path $outputBaseDir "another_sample_output.csv"
    #     ExpectedToSucceed = $true
    # }
    # @{
    #     Name = "EmptyFile_Handling"
    #     InputFile = Join-Path $samplesDir "empty_sample.md" # 空のMDファイルを用意
    #     OutputFile = Join-Path $outputBaseDir "empty_sample_output.csv"
    #     ExpectedToSucceed = $true # エラーなく空のCSVまたは警告が出ることを期待
    # }
    # @{
    #     Name = "NonExistentFile_ErrorHandling"
    #     InputFile = Join-Path $samplesDir "non_existent_sample.md" # 存在しないファイル
    #     OutputFile = Join-Path $outputBaseDir "non_existent_sample_output.csv"
    #     ExpectedToSucceed = $false # スクリプトがエラーで終了することを期待
    # }
)

# --- テスト実行 ---
$allTestsPassed = $true
Write-Host "テスト実行開始..." -ForegroundColor Green

foreach ($testCase in $testCases) {
    Write-Host ("-"*40)
    Write-Host "テストケース: $($testCase.Name)"
    Write-Host "入力ファイル: $($testCase.InputFile)"
    Write-Host "出力ファイル: $($testCase.OutputFile)"

    $success = $false
    try {
        if (-not (Test-Path $testCase.InputFile) -and $testCase.ExpectedToSucceed) {
            Write-Warning "入力ファイルが見つかりません: $($testCase.InputFile)"
            # このケースは ExpectedToSucceed = $false にするべきかもしれない
        }

        # メインスクリプト実行
        & $mainScriptPath -InputFilePath $testCase.InputFile -OutputCsvPath $testCase.OutputFile -Verbose # -ErrorAction Stop をつけるとより厳密

        # 簡単な成功判定: 出力ファイルが生成されたか
        if (Test-Path $testCase.OutputFile) {
            # さらに詳細なチェックが必要な場合はここに追加
            # 例: Compare-Object (Get-Content $testCase.OutputFile) (Get-Content $expectedOutputFile)
            #     特定の行数やヘッダーが存在するかなど
            Write-Host "  結果: 出力ファイルが生成されました。"
            $success = $true
        } else {
            Write-Warning "  結果: 出力ファイルが生成されませんでした。"
            $success = $false
        }

    } catch {
        Write-Error "  テストケース実行中にエラーが発生しました: $($_.Exception.Message)"
        $success = $false
    }

    if ($success -eq $testCase.ExpectedToSucceed) {
        Write-Host "  ステータス: PASSED" -ForegroundColor Green
    } else {
        Write-Host "  ステータス: FAILED" -ForegroundColor Red
        $allTestsPassed = $false
    }
}

Write-Host ("-"*40)
if ($allTestsPassed) {
    Write-Host "全てのテストケースが成功しました。" -ForegroundColor Green
} else {
    Write-Host "失敗したテストケースがあります。" -ForegroundColor Red
}
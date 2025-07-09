# PowerShellスクリプト実行ガイド

## 推奨される実行方法 (WSL環境)

WSL (Windows Subsystem for Linux) 環境から、Windows上にインストールされた PowerShell Core (`pwsh.exe`) のスクリプトを実行する場合、**`pwsh.exe` を直接呼び出す方法が最も安定しており、推奨されます。**

この方法は、`cmd.exe` を介することで発生する複雑な引用符のエスケープや、予期せぬエラー（`SecurityError` や `ParserError` など）を回避できます。

### 基本コマンド形式

```bash
pwsh.exe -ExecutionPolicy Bypass -File "<Windows形式のスクリプトパス>" -<パラメータ名> "<Windows形式のパラメータ値>"
```

*   **`pwsh.exe`**: Windows側のPowerShell実行ファイルを直接指定します。
*   **`-ExecutionPolicy Bypass`**: 実行ポリシーの問題を回避するために指定します。
*   **`-File "<Windows形式のスクリプトパス>"`**: 実行するスクリプトを、`C:\Users\YourUser\...` のようなWindows形式の絶対パスで指定します。
*   **`-<パラメータ名> "<Windows形式のパラメータ値>"`**: スクリプトに渡すパラメータも、同様にWindows形式のパスで指定します。

### 実行例

```bash
# Convert-CsvToSimpleMdWbs.ps1 を実行する例
pwsh.exe -ExecutionPolicy Bypass -File "C:\Temp\MD-WBS-Tools\src\powershell\Convert-CsvToSimpleMdWbs.ps1" -InputCsvPath "C:\Temp\MD-WBS-Tools\test_outputs\numbering\numbered_wbs.csv" -OutputMdPath "C:\Temp\MD-WBS-Tools\test_outputs\output.md"
```

---

## その他の実行方法

### Windows PowerShellコンソールから直接実行する場合

PowerShellコンソール (`pwsh.exe`) を直接開いて実行する場合の基本的なコマンドです。

```powershell
pwsh -File "<スクリプトのパス>" -<パラメータ名> "<パラメータの値>"
```

**実行例:**
```powershell
pwsh -File "C:\Temp\MD-WBS-Tools\src\powershell\Convert-ExcelToSimpleMdWbs.ps1" -ExcelPath "C:\Temp\MD-WBS-Tools\samples\excel_examples\simple-markdown-wbs-gantt-sample.xlsx" -OutputPath "C:\Temp\MD-WBS-Tools\test_output.md"
```

### 【非推奨】cmd.exe を経由する方法

**注意:** この方法は、過去のバージョンとの互換性や、特殊な環境下でのトラブルシューティングのために残されていますが、**現在は非推奨**です。引用符の扱いやエラーハンドリングが複雑になり、予期せぬ問題を引き起こす可能性があります。

```bash
cmd.exe /c "pwsh -File ""<Windows形式のスクリプトパス>"" -<パラメータ名> ""<Windows形式のパラメータ値>"" "
```

---
## UNC パスに関する注意点

WSL環境からWindowsのファイルにアクセスする場合、パスの形式に注意してください。UNCパス (`\\wsl.localhost\...` や `\\wsl$\...`) はPowerShellで正しく解釈されない場合があるため、常にWindows側の絶対パス (`C:\...`) を使用することを推奨します。


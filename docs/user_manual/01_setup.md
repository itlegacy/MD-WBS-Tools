# 1. セットアップ

MD-WBS-Toolsを利用するための環境設定について説明します。

## 1.1. PowerShell環境

* **PowerShellのバージョン:** 本ツール群はPowerShell 7.3以上での動作を推奨します。
  * バージョンの確認方法: PowerShellコンソールで `$PSVersionTable.PSVersion` を実行。
  * インストール/アップグレード: [Microsoft PowerShell GitHub](https://github.com/PowerShell/PowerShell) などを参照。
* **実行ポリシー:** PowerShellスクリプトの実行が許可されている必要があります。
  * 確認: `Get-ExecutionPolicy`
  * 変更（必要な場合、管理者権限で）: `Set-ExecutionPolicy RemoteSigned`（推奨）または `Set-ExecutionPolicy Unrestricted`（開発時など、リスクを理解した上で）。
  * スコープを限定することも可能です（例: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`）。

## 1.2. ツールの入手と配置

* 本ツール群は、指定の`プロジェクトフォルダ`（リポジトリ）から入手してください。
* `src/powershell/` ディレクトリ配下のスクリプト（`.ps1`）およびモジュール（`Modules/MyCommonFunctions/`）を、任意の作業ディレクトリに配置するか、パスを通してください。
*（詳細な配布・インストール方法が決まり次第追記）

## 1.3.（推奨）Visual Studio Code と拡張機能

`simple-md-wbs` ファイルの編集およびMarkmapによる視覚化のために、以下の環境を推奨します。

* **Visual Studio Code（VS Code）:** 最新版をインストール。
* **推奨VS Code拡張機能:**
  * **Markmap（`vscode-markmap`など）:** `simple-md-wbs` ファイルを開きながら、リアルタイムでWBSツリーをプレビューできます。
  * **Markdown All in One（または類似のMarkdown支援拡張）:** Markdownの編集を効率化します。
  * **PowerShell拡張機能（`ms-vscode.powershell`）:** VS Code内でPowerShellスクリプトを編集・実行・デバッグできます。

## 1.4.（オプション）Excelテンプレートの準備

* 出力されるCSVファイルは、汎用的なWBS/ガントチャートExcelテンプレート（`samples/excel_templates/simple-markdown-wbs-gantt-template.xlsx`）での利用を想定しています。
* このテンプレートを参考に、ご自身のExcel環境を準備するか、直接このテンプレートを利用してください。
* とくに、日付計算を行う場合は、Excelの計算式をテンプレートに設定しておくと便利です（[Excelでの活用（`05_excel_integration.md`）]を参照）。

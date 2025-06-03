# MD-WBS-Tools 開発ロードマップ（simple-md-wbs 中心アプローチ + VBA連携）

## 全体方針

* **`simple-md-wbs` を中核に:** すべてのWBSデータは `simple-md-wbs` 記法（詳細は [`docs/12_wbs_task_syntax_specification.md`](./12_wbs_task_syntax_specification.md) を参照）をマスターデータとし、この記法からの変換およびこの記法への変換を基本とする。
* **Markdown互換性と視覚化:** `simple-md-wbs` は標準的なMarkdown構文を最大限活用し、VS Code等の`エディタ`での編集容易性と、Markmap等によるリアルタイムな構造視覚化を重視する。
* **標準CSV連携をPowerShellの責務に:** PowerShellスクリプトは、`simple-md-wbs` の論理構造を忠実に反映した「標準順序CSV」の生成と解釈に注力する。
* **Excel特殊表示はVBAマクロで対応（オプション）:** Excelのグループ化機能に最適化されたタスクの並び順など、表示特化の処理は、別途開発・提供を検討するオプションのExcel VBAマクロに委任する。
* 段階的開発とテスト重視: 各フェーズで具体的な価値を提供し、コア機能の品質を確保するために単体テスト・結合テストを重視する。
* PowerShellモジュール化: 共通処理は `MyCommonFunctions` モジュールに集約し、保守性と再利用性を高める。

---

## 開発フェーズ

### フェーズ 0: 基盤整備、ドキュメントFIX、コア機能テスト完了（完了）

* **目的:**
  * 新しい `simple-md-wbs` 記法の仕様を正式にドキュメント化し、関連する主要プロジェクトドキュメントを更新・FIXする。
  * プロトタイプで検証済みの `simple-md-wbs` → CSV変換のコアロジックをリファクタリングし、モジュール化し、単体テストを整備する。
* **主要タスク:**
    1. [`simple-md-wbs` 仕様書 (`12_wbs_task_syntax_specification.md`)](./12_wbs_task_syntax_specification.md) のFIX。 **（完了）**
    2. 本ロードマップ（`01_project_roadmap.md`）のFIX。 **（本レビューでFIX）**
    3. [README (`00_README.md`)](./00_README.md) のFIX。 **（完了）**
    4. [要件定義書 (`10_requirements_definition.yaml`)](./10_requirements_definition.yaml) のFIX。 **（完了）**
    5. `Convert-SimpleMdWbsToCsv.ps1` のリファクタリング（PowerShellベストプラクティス適用、エラーハンドリング基礎、ログ出力整備）。 **（完了）**
    6. 共通関数（`Get-DecodedAndMappedAttribute`, `ConvertTo-AttributeObject`, `Reset-WbsCounters`）の `MyCommonFunctions` モジュールへの移動とマニフェスト整備。 **（完了）**
    7. `MyCommonFunctions` モジュール内主要関数の単体テスト作成と全テストパス。 **（完了）**
* **成果物:**
  * FIXされた主要ドキュメント群。
  * リファクタリングされモジュール化された、単体テスト済みの `Convert-SimpleMdWbsToCsv.ps1`（基本機能版）と `MyCommonFunctions` モジュール。

---

### フェーズ 1: `SimpleMdWbs` → 標準順序CSV 変換機能の完成度向上（次期作業）

* **目的:**
  * `simple-md-wbs` からCSVへの変換機能について、依存関係の解決を含め、より実用的なレベルまで完成度を高める。
  * ユーザーが実際に利用開始できるレベルの品質とドキュメントを提供する。
* **主要タスク:**
    1. **依存関係解決機能の実装（`Convert-SimpleMdWbsToCsv.ps1`）:**（最優先）
        * 「先行タスクユーザー記述ID」を解決し、対応するアイテムの「表示用ソートキー」と「名称」をCSVに出力。
        * 未解決IDに対する警告処理。
    2. **CSV出力列の最終調整:** Excelテンプレート（`wbs-gantt-template.xlsx`）との整合性を最終確認し、CSVの列名と出力内容をFIXする（要件定義書のCSV列定義に基づき実装）。
    3. **結合テストの拡充:** 依存関係を含む多様な `simple-md-wbs` ファイルを用いた結合テストを実施し、出力CSVの正確性を検証。
    4. **ユーザーマニュアル（`docs/user_manual/`）の作成（本フェーズ機能分）:**
        * `simple-md-wbs` の記述方法詳細、`Convert-SimpleMdWbsToCsv.ps1` の使い方、出力CSVの解説、トラブルシューティング等を記述。
    5. **（検討）PowerShell側での日付計算機能の基本検討:** ユーザー入力の日付・日数をそのまま出力する現在の仕様を維持しつつ、将来的な日付自動計算の可能性について基本的な調査やアイデア出しを行う（実装は別フェーズ）。
* **成果物:**
  * 依存関係解決機能を含む、安定動作する `Convert-SimpleMdWbsToCsv.ps1`。
  * 詳細なユーザーマニュアル（`SimpleMdWbs`→CSV変換）。
  * 充実した結合テストケース群。

---

### フェーズ 2: 標準順序CSV → `SimpleMdWbs` 逆変換機能の開発（計画中）

* **目的:**
  * 標準順序CSV形式のファイルを読み込み、`simple-md-wbs` 形式に変換する機能を提供する。
* **主要タスク:**
    1. CSV入力仕様の定義（どの列をどの属性にマッピングするか、必須/任意項目など）。
    2. `Convert-CsvToSimpleMdWbs.ps1` の設計と実装（変換ロジック）。
    3. 単体テストおよび結合テストの実施。
    4. ユーザーマニュアルの作成。
* **成果物:**
  * `Convert-CsvToSimpleMdWbs.ps1` スクリプト。
  * CSV→`SimpleMdWbs` 変換に関するユーザーマニュアル。

---

### フェーズ 3: Excel表示最適化VBAマクロの開発（オプション・計画中）

* **目的:**
  * PowerShellスクリプトが出力した標準順序CSVファイルを、Excel上でWBSを見やすく表示するためのVBAマクロを提供する。
* **主要タスク:**
    1. Excel VBAマクロの仕様定義（表示形式、操作性など）。
    2. VBAコードの実装。
    3. テストの実施。
    4. ユーザーマニュアルへの追記。
* **成果物:**
  * Excel表示最適化VBAマクロ。
  * VBAマクロに関するユーザーマニュアル。

---

### フェーズ 4: 安定化、改善、および拡張機能検討（将来）

* **目的:**
  * `simple-md-wbs` 記法および関連ツールの安定性を向上させ、ユーザーからのフィードバックに基づいて改善を行う。
  * 将来的な拡張機能について検討し、実現可能性や優先順位を評価する。
* **タスク例:**
  * PowerShell側での日付自動計算機能の実装（もしフェーズ1の検討で必要と判断されれば）。
  * Markwhen連携機能の再検討と実装（需要と実現性を見極める）。
  * より高度なエラーハンドリングとユーザーへのフィードバック強化（PowerShell側）。
  * テストカバレッジの向上（PowerShell側）。
  *（優先度低）Excel COMオブジェクトによる直接連携（VBAマクロの評価とユーザー需要次第）。
* **成果物:**
  * 安定性とユーザビリティが向上した `simple-md-wbs` 関連ツール。
  * 将来的な拡張機能に関する調査報告書。

---

## 変更履歴

| 日付       | バージョン | 担当者    | 変更内容 |
|------------|------------|-----------|----------|
| 2025-06-02 | 2.2        | IT Legacy | VBAマクロ連携によるExcel表示最適化の方針を反映。PowerShellの責務を明確化し、VBA開発フェーズを追加。 |
| 2025-05-31 | 2.0        | IT Legacy | `simple-md-wbs` 中心アプローチへの移行を反映。CSV連携優先、COM連携は将来検討へ。 |
| 2025-05-30 | 1.0        | IT Legacy | 初版作成。WBSタスク記法を軸とした開発フェーズ、フロントマターの段階的導入方針などを定義。 |

---

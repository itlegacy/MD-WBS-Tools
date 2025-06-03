# MD-WBS-Tools プロジェクトへようこそ

## 概要

`simple-md-wbs` は、Markdownをベースとした軽量なWBS（Work Breakdown Structure）記述記法です。
テキスト形式のため、バージョン管理システムとの連携が容易で、可読性が高く、特別な`エディタ`を必要としません。

本プロジェクトでは、`simple-md-wbs` 形式のファイルをPowerShellスクリプトで解析し、**標準順序CSV** 形式に変換します。
ExcelでのWBS表示最適化は、**オプションのExcel VBAマクロ** を利用して実現します。

## 主な機能（`simple-md-wbs` 中心）

1. **`simple-md-wbs` ⇔ 標準順序CSV 双方向変換（段階的に実現）:**
    * 「`simple-md-wbs` 記法」で記述されたテキストファイルと、**標準的な階層順序（カテゴリが先、タスクが後）を持つCSVファイル**間でのデータ相互変換。
    * まずは `simple-md-wbs` → 標準順序CSV変換を実現します。（将来的には逆変換も目指します）
2. **（オプション）Excel表示最適化VBAマクロ:**
    * PowerShellスクリプトが出力した標準順序CSVを、Excelのグループ化機能に適した表示順序に並べ替えるマクロ。
    * および、その特殊な順序から標準順序CSVに戻す逆変換マクロ。
3. **（連携）`simple-md-wbs` → Markmap（視覚化）:**
    * `simple-md-wbs` は標準的なMarkdownの階層構造を利用するため、VS CodeのMarkmap拡張機能などと連携することで、WBSのツリー構造をリアルタイムに視覚化できます。本ツール群が直接Markmapファイルを生成するわけではありませんが、`simple-md-wbs` の設計思想としてMarkmapとの親和性を重視しています。
4. **（検討中）`simple-md-wbs` → Markwhen 変換:**
    * `simple-md-wbs` から[Markwhen](https://markwhen.dev/)形式のテキストを生成し、タイムラインの視覚化を支援する機能（従来構想にあったもの。`simple-md-wbs` からの実現可能性と優先度を再検討）。

詳細な開発計画については、[プロジェクトロードマップ（01_project_roadmap.md）](./01_project_roadmap.md)を参照してください。

## `simple-md-wbs` 記法について

本ツール群の中核となるWBS記述方法です。詳細は [`simple-md-wbs` 記法 仕様書](./12_wbs_task_syntax_specification.md) を必ずご確認ください。主な特徴は以下の通りです。

* Markdownの見出し（H1～H4）でプロジェクト～小分類の階層を表現。
* タスクはリストアイテム（`-` または `*`）で記述。
* 各カテゴリやタスクの名称は短く保ち、Markmapでの視認性を向上。
* 詳細な属性（日付、担当者、進捗率など）は、カテゴリの場合は専用の `%%` で始まる行に、タスクの場合はHTMLコメント `<!-- ... -->` 内にカンマ区切りで記述。

## ターゲットユーザー

* Markdownでの文書作成に慣れており、テキストベースでWBSを管理したい方。
* VS Codeを主要な作業環境とし、Markmapなどの視覚化ツールと連携させたい開発者、プロジェクトリーダー、PMO担当者。
* トップダウンでの目標設定とボトムアップでのタスク詳細化を柔軟に組み合わせたい方。
* 軽量でカスタマイズ可能なWBS管理ソリューションをローカル環境で利用したい方。
* Excelでの進捗管理やデータ共有を行いつつ、WBSの構造設計はテキストベースで行いたい方。

## このドキュメント群について

この `docs` `フォルダ`には、MD-WBS-Toolsプロジェクトに関するさまざまなドキュメントが格納されています。

* [`00_README.md(このファイル)`](./00_README.md): プロジェクトの概要とドキュメントの入り口。
* [`01_project_roadmap.md`](./01_project_roadmap.md): プロジェクト全体の開発計画と各フェーズの目標（新しい `simple-md-wbs` 方針に基づく）。
* [`05_development_charter.md`](./05_development_charter.md): プロジェクトの開発哲学、品質目標などを定めた開発憲章。
* [`10_requirements_definition.yaml`](./10_requirements_definition.yaml): プロジェクトの要件定義書（新しい `simple-md-wbs` 方針に基づく）。
* **[`12_wbs_task_syntax_specification.md`](./12_wbs_task_syntax_specification.md): 本ツール群のもっとも重要な仕様書。`simple-md-wbs` 記法の詳細な定義。WBSを作成・編集する方はまずこちらをご確認ください。**
* [`90_coding_standards.md`](./90_coding_standards.md): PowerShellスクリプト開発時のコーディング規約。
* `user_manual/`: 各ツールのセットアップ方法、使用方法などを記述したユーザーマニュアル（順次拡充）。
* [`11_mdwbs_original_syntax.yaml`](./11_mdwbs_original_syntax.yaml): 旧WBS記法構想のアーカイブ資料。

プロジェクトへの貢献やフィードバックも歓迎します。

---

## 変更履歴

| 日付       | バージョン | 担当者      | 変更内容                                                                            |
|------------|------------|-------------|-------------------------------------------------------------------------------------|
| 2025-06-03 | 2.3        | IT Legacy   | simple-md-wbsの属性リスト更新（状態削除、進捗率%のみ）を反映。                   |
| 2025-06-02 | 2.2        | IT Legacy   |  VBAマクロ連携によるExcel表示最適化の方針を反映。PowerShellの責務を明確化。         |
| 2025-05-31 | 2.1        | IT Legacy   | `simple-md-wbs` 中心への方針転換を反映。概要、機能、関連ドキュメント構成を更新。    |
| 2025-05-29 | 1.1        | IT Legacy   | トップダウン/ボトムアップ計画への対応を概要と機能説明に反映。開発憲章への言及追加。 |

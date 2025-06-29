# MD-WBS-Tools へようこそ

## 1. プロジェクトの目的

このプロジェクトの主な目的は、**Excelで管理されているWBS（Work Breakdown Structure）を、Microsoft Copilotがもっとも理解しやすい`simple-md-wbs`形式へ変換すること**です。

多くのプロジェクト現場ではWBSがExcelで管理されていますが、その構造（例: サマリータスクが下にある）や数式は、そのままではAIが正しく解釈するのが困難な場合があります。本ツールは、そのギャップを埋めるための変換ツールを提供します。

## 2. 主な機能

開発は以下のフェーズで段階的に進められます。詳細は[プロジェクトロードマップ](./01_project_roadmap.md)を参照してください。

1. **Excel → `simple-md-wbs` 変換（最優先）**
    * ローカルのExcelファイルから基本的なWBS情報を読み取り、Copilotが解釈しやすい`simple-md-wbs`形式のMarkdownファイルを出力します。
    * 将来的には、Excelの数式やグループ化情報を解析し、よりリッチな情報を変換する機能の高度化を目指します。

2. **`simple-md-wbs` ⇔ CSV 相互変換**
    * `simple-md-wbs`形式のファイルを、ガントチャートツールなど他のツールと連携しやすい標準的なCSV形式に変換します。
    * CSVファイルから`simple-md-wbs`形式への逆変換もサポートします。

3. **MarkmapによるWBSの視覚化**
    * `simple-md-wbs`は標準的なMarkdownの階層構造を利用しているため、VS CodeのMarkmap拡張機能などと連携し、WBSのツリー構造をリアルタイムに視覚化できます。

## 3. `simple-md-wbs` 記法について

本ツール群の中核となる、Markdownベースの軽量なWBS記述方法です。詳細は**[`simple-md-wbs` 記法 仕様書](./12_wbs_task_syntax_specification.md)**を必ずご確認ください。

* Markdownの見出し（H1～H4）でプロジェクトの階層を表現します。
* タスクはリストアイテム（`-` または `*`）で記述します。
* 日付、担当者、進捗率などの詳細な属性は、HTMLコメント `<!-- ... -->` 内に記述します。

## 4. ターゲットユーザー

* **ExcelでWBSを管理しており、その情報をMicrosoft Copilotで活用したい方。**
* テキストベースでWBSのバージョン管理を行いたい開発者、プロジェクトリーダ、PMO担当者。
* VS Codeを主要な作業環境とし、Markmapなどの視覚化ツールと連携させたい方。

## 5. 開発者向け情報

AIアシスタントとの協業プロセスやコーディング規約など、開発に関する詳細な情報は以下のドキュメントを参照してください。

* [`99_ai_collaboration_guideline.md`](./99_ai_collaboration_guideline.md): AIアシスタントとの協業ガイドライン
* [`05_development_charter.md`](./05_development_charter.md): プロジェクト開発憲章
* [`90_coding_standards.md`](./90_coding_standards.md): コーディング規約

---

## 変更履歴

| 日付 | バージョン | 担当者 | 変更内容 |
| :--- | :--- | :--- | :--- |
| 2025-06-29 | 3.0 | AI Assistant | 新しいロードマップに基づき、プロジェクトの目的を「Excel→Copilot連携」に明確化。機能説明を再構成。 |
| 2025-06-03 | 2.3 | IT Legacy | simple-md-wbsの属性リスト更新（状態削除、進捗率%のみ）を反映。 |
| 2025-06-02 | 2.2 | IT Legacy | VBAマクロ連携によるExcel表示最適化の方針を反映。 |
| 2025-05-31 | 2.1 | IT Legacy | `simple-md-wbs` 中心への方針転換を反映。 |
| 2025-05-29 | 1.1 | IT Legacy | トップダウン/ボトムアップ計画への対応を概要と機能説明に反映。 |

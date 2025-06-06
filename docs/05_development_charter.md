# MD-WBS-Tools 開発憲章 (Development Charter)

## 1. 序文

このドキュメントは、「MD-WBS-Tools」プロジェクトにおけるソフトウェア開発の基本原則、品質目標、および実践的なガイドラインを定めるものです。
本憲章は、開発者（人間、AIアシスタントを含む）が共通の理解と目的に基づいて協力し、持続可能で高品質なツールセットを構築するための指針となります。
過去のプロジェクトにおける経験と教訓を活かし、技術的負債を管理し、将来の変更に強いソフトウェア開発を目指します。
この憲章は「生きた文書」であり、プロジェクトの進行とともに見直され、改善されていきます。

## 2. 開発哲学

以下の5つの哲学を、日々の開発活動における判断基準とします。

1. **「意図」の明示化と共有（Clarity of Intent）**:
    コードの各部分が「何をするのか」「なぜそうするのか」を明確に表現します。これには、意味のある命名、厳密な型指定、適切なコメント、明確な関数シグネチャ、モジュール設計が含まれます。
2. **「単純さ」の追求（Simplicity）**:
    複雑なコードは避け、単一責任の原則に従い、関数やモジュールを小さく保ちます。PowerShellの標準的な機能やイディオムを可能な限り活用し、複雑な処理は小さなステップに分割します。
3. **「影響範囲」の意識と管理（Consciousness of Impact）**:
    コード変更や機能実行が、システムの他部分や外部環境（ファイルシステム、COMオブジェクト等）に与える影響を常に意識します。スコープ管理、副作用最小化、リソース解放、エラーハンドリングを通じて影響範囲を制御します。
4. **「再現性」と「予測可能性」の確保（Reproducibility and Predictability）**:
    同じ入力に対して常に同じ結果を返し、コードの動作が予測可能であることを目指します。厳密な入力検証、状態管理の明確化、網羅的なテストを通じてこれを実現します。
5. **「学習」と「改善」の継続（Continuous Learning and Improvement）**:
    開発プロセスで発生した問題やエラーを貴重な学習機会と捉え、得られた教訓を本憲章やコーディングスタンダード、開発プロセス自体に反映し、将来の同様の問題を防ぎます。

## 3. 品質目標

本プロジェクトでは、以下の品質特性を重視します。

* **堅牢性 (Robustness)**: エラーや予期せぬ入力に対しても安定して動作し、クラッシュしにくい。
* **保守性 (Maintainability)**: コードが理解しやすく、修正や機能追加が容易になる。
* **拡張性 (Extensibility)**: 新しい機能やデータ形式への対応が、既存の構造を大きく破壊することなく行える。
* **ユーザーフレンドリー (User-friendliness)**: ツールの利用方法が直感的で分かりやすく、ドキュメントが整備されている。**多様なプロジェクトマネジメントスタイル（トップダウン計画、ボトムアップ詳細化、それらの組み合わせ）をサポートできる柔軟性を含む。**
* **柔軟性 (Flexibility)**: さまざまなユーザーの計画・管理スタイルに対応できること。

## 4. 技術的負債への対処方針

技術的負債は避けられないものと認識し、放置せずに計画的に対処します。

1. **認識と記録**:
    * 開発中に発見された技術的負債（例: 不適切な設計、非効率なコード、テスト不足、ドキュメントの不備など）は、GitHub Issues（導入する場合）やコード内のコメント（`TODO:`, `FIXME:`）で明確に記録します。
2. **段階的解消**:
    * **基本方針**:「新しい機能が必要な場合は、まず新しい関数/モジュールとして追加し、既存の安定した部分への影響を最小限に抑える。その後、計画的に時間を確保してリファクタリングを行う。」
    * **リファクタリングのトリガー**:
        * 大きな機能追加や変更のタイミング。
        * 特定のモジュールや関数の修正頻度が異常に高い場合。
        * パフォーマンス上のボトルネックが特定された場合。
        * コードの理解や修正に過大な時間を要すると感じた場合。
    * **優先順位付け**: リファクタリングは、影響範囲、改善効果、緊急性を考慮して優先順位を付けます。
3. **予防策**:
    * 本憲章および「コーディングスタンダード (`90_coding_standards.md`)」の遵守。
    * コードレビュー（セルフレビュー含む）の実施。
    * テストの充実。
    * **多様なユースケースの考慮**: 設計・実装段階で、ユーザーが実際にどのようにツールを使うか（例: トップダウンでの計画、途中からの詳細化など）を具体的に想定し、それに対応できるような一般性と柔軟性を持たせるよう努める。

## 5. `MyCommonFunctions` モジュールへの変更ポリシー

コアとなる `MyCommonFunctions` モジュールは、プロジェクト全体の安定性の鍵です。その変更はとくに慎重に行います。

1. **下位互換性の維持**: 原則として、公開されている関数の`インターフェース`（`パラメータ名`、型、順序、戻り値の型）は変更しません。
2. **既存安定関数の変更**:
    * **許可される場合**: 重大なバグ修正、セキュリティ上の脆弱性対応、プロファイリングによって明確に示された深刻なパフォーマンス問題の改善。
    * **原則避けるべき**: 上記以外での安易なロジック変更や`インターフェース`変更。
3. **新機能・`インターフェース`変更の追加**:
    * 既存関数を直接変更するのではなく、**新しい関数として追加する**ことを第一選択とします。
    * 既存関数をラップして新しい機能を提供するヘルパー関数を作成することも有効です。
    * やむを得ず`インターフェース`を変更する場合は、旧関数を `Obsolete` 属性でマークし、明確な移行パスを示した新関数を提供します。
4. **バージョン管理**:
    * モジュールマニフェストファイル（`MyCommonFunctions.psd1`）の `ModuleVersion` は、意味のある変更があった場合にセマンティックバージョニング（例: `1.0.0` -> `1.0.1`（パッチ）, `1.1.0`（マイナー）, `2.0.0`（メジャー））にしたがって更新します。
    * 変更内容は、コミットメッセージおよびモジュールの変更履歴（もし設けるなら）に記録します。

## 6. ドキュメント更新の義務

ソフトウェアの品質は、コードだけでなくドキュメントの品質にも依存します。

1. **同期の徹底**: 仕様変更、設計変更、APIの変更、`ユーザーインターフェース`の変更など、コードに大きな変更が加えられた場合は、関連するすべてのドキュメントも**必ず同時に更新**します。
    * 対象ドキュメント例: `01_project_roadmap.md`, `10_requirements_definition.yaml`, `12_wbs_task_syntax_specification.md`, 各ユーザードキュメント。
2. **明確性と正確性**: ドキュメントは、対象読者（ユーザー、開発者）にとって明確かつ正確であるように記述します。
3. **変更履歴の活用**: 主要ドキュメントには「変更履歴」セクションを設け、いつ、誰が、何を更新したかを記録します。

## 7. テスト方針

品質目標を達成するため、テストは開発プロセスの不可欠な部分です。

1. **手動テストの重視**: 詳細なテストケース（正常系、準正常系、異常系、境界値）に基づき、主要機能の変更時には徹底した手動テストを実施します。テスト結果は記録します。
2. **簡易自動テストの導入検討**: `MyCommonFunctions` などのコアロジックに対しては、PowerShell標準機能を用いた入力と期待出力の検証スクリプトを作成し、リグレッションの早期発見を目指します。
3. **Pesterの状況注視**: Pesterの利用に関する問題が解決されれば、より本格的なユニットテスト/統合テストの導入を再検討します。

## 8. 変更履歴の管理

プロジェクト全体の変更追跡と透明性を確保します。

1. **Gitコミットメッセージ規約**:「コーディングスタンダード（`90_coding_standards.md`）」で定義されたコミットメッセージ規約（例: Conventional Commits）を遵守します。これにより、コミット履歴自体が意味のある変更ログとなります。
2. **ドキュメント内変更履歴**: 主要ドキュメントには、ファイル内に専用の「変更履歴」セクションを設けます。

## 9. AIアシスタントとの協業ガイドライン (オプション)

AI支援ツールを開発に利用する場合、以下の点を心がけます。

1. **明確な指示（プロンプト）**: AIに対しては、背景、目的、制約条件、期待する出力形式などを具体的かつ明確に伝えます。
2. **提案の検証**: AIによって生成されたコードやドキュメントは、そのまま鵜呑みにしない。常に人間が内容を理解し、テストし、本憲章やスタンダードに照らして検証・修正します。
3. **段階的な利用**: 最初から複雑なタスクを任せるのではなく、部分的なコード生成やドキュメントの草案作成などから始め、徐々に複雑なタスクへと範囲を広げる。いずれの場合も、必ず人間が内容を理解し、テストし、本憲章やスタンダードに照らして検証・修正します。
4. **責任の所在**: AIの提案を利用した場合でも、最終的な成果物の品質に対する責任は開発者自身にあります。

---

## 変更履歴

| 日付       | バージョン | 担当者      | 変更内容                                     |
|------------|------------|-------------|----------------------------------------------|
| 2025-05-29 | 1.1        | AI/ユーザー | 品質目標に柔軟性を追加、トップダウン/ボトムアップ計画への対応を憲章に反映。 |
| 2025-05-29 | 1.0        | AI/ユーザー | 初版作成。                                     |

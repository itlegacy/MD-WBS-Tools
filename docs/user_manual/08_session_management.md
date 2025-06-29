# 08. セッション状態の管理

このドキュメントでは、Gemini CLIエージェントのセッション状態を手動で管理するためのスクリプトの使い方を説明します。これらのスクリプトを使用することで、作業の中断と再開に役立てることができます。

**注意:** これらのスクリプトは自動で実行されるものではなく、ユーザーが `run_shell_command` ツールを使って明示的に実行する必要があります。また、エージェントの内部状態（現在の計画やステップなど）を自動で取得してスクリプトに渡す機能は、現在のエージェントの能力にはありません。必要な情報は手動で指定してください。

## スクリプトの場所

これらのスクリプトは、プロジェクトルートの `scripts` ディレクトリに配置されています。

- `scripts/save_session_state.py`: 現在のセッション状態をファイルに保存します。
- `scripts/load_session_state.py`: 保存されたセッション状態ファイルを読み込んで内容を表示します。
- `scripts/reset_session_state.py`: 保存されたセッション状態ファイルを���除します。

## 1. セッション状態を保存する（`save_session_state.py`）

現在のエージェントとの作業状態をファイルに保存します。これにより、あとで作業を再開する際に、どのような状況だったかを確認できます。

以下の形式で `run_shell_command` ツールを使って実行します。

```bash
run_shell_command command="python /mnt/c/Temp/MD-WBS-Tools/scripts/save_session_state.py --output_path /mnt/c/Temp/MD-WBS-Tools/.gemini_session_state.json --task_description '現在のタスク概要をここに記入' --current_plan '現在の計画をここに記入' --completed_steps '["完了ステップ1", "完了ステップ2"]' --pending_steps '["未完了ステップ1", "未完了ステップ2"]' --context_files '["/path/to/file1.txt", "/path/to/file2.ps1"]'" description="現在のセッション状態をファイルに保存します。"

```

**`パラメータ`:**

- `--output_path`（必須）: 状態ファイルを保存するパスを指定します。プロジェクトルートに `.gemini_session_state.json` のような隠しファイルとして保存するのが一般的です。
- `--task_description`（任意）: 現在のタスクの概要を文字列で指定します。
- `--current_plan`（任意）: 現在の計画を文字列で指定し��す。
- `--completed_steps`（任意）: 完了したステップのリストを **JSON形式の文字列** で指定します。例: `'["ステップA", "ステップB"]'`
- `--pending_steps`（任意）: 未完了のステップのリストを **JSON形式の文字列** で指定します。例: `'["ステップC", "ステップD"]'`
- `--last_tool_call`（任意）: 直前のツール呼び出し情報を **JSON形式の文字列** で指定します。例: `'{"tool_name": "read_file", "parameters": {"absolute_path": "/path/to/file.txt"}, "result": {"output": "..."}}'`
- `--context_files`（任意）: 作業に関連するファイルパスのリストを **JSON形式の文字列** で指定します。例: `'["/path/to/file1.txt", "/path/to/file2.ps1"]'`

**実行例:**

```bash
run_shell_command command="python /mnt/c/Temp/MD-WBS-Tools/scripts/save_session_state.py --output_path /mnt/c/Temp/MD-WBS-Tools/.gemini_session_state.json --task_description 'エラーハンドリング改善の続き' --current_plan 'Convert-SimpleMdWbsToCsv.ps1の警告対応' --pending_steps '["テキストが空のアイテムの警告追加"]' --context_files '["/mnt/c/Temp/MD-WBS-Tools/src/powershell/Convert-SimpleMdWbsToCsv.ps1"]'" description="現在のセッション状態をファイルに保存します。"
```

## 2. セッション状態を読み込んで表示する（`load_session_state.py`）

保存されたセッション状態ファイルの内容を読み込み、標準出力に表示します。レジューム時に前回の状態を確認するのに役立ちます。

以下の形式で `run_shell_command` ツールを使って実行します。

```bash
run_shell_command command="python /mnt/c/Temp/MD-WBS-Tools/scripts/load_session_state.py --input_path /mnt/c/Temp/MD-WBS-Tools/.gemini_session_state.json" description="保存されたセッション状態を読み込んで表示します。"
```

**`パラメータ`:**

- `--input_path`（必須）: 読み込む状態ファイルのパスを指定します。

**実行例:**

```bash
run_shell_command command="python /mnt/c/Temp/MD-WBS-Tools/scripts/load_session_state.py --input_path /mnt/c/Temp/MD-WBS-Tools/.gemini_session_state.json" description="保存されたセッション状態を読み込んで表示します。"
```

## 3. セッション状態をリセットする（`reset_session_state.py`）

保存されたセッション状態ファイルを削除します。新しいタスクを開始する場合などに使用します。

以下の形式で `run_shell_command` ツールを使って実行します。

```bash
run_shell_command command="python /mnt/c/Temp/MD-WBS-Tools/scripts/reset_session_state.py --target_path /mnt/c/Temp/MD-WBS-Tools/.gemini_session_state.json" description="保存されたセッション状態ファイルを削除します。"
```

**`パラメータ`:**

- `--target_path`（必須）: 削除する状態ファイルのパスを指定します。

**実行例:**

```bash
run_shell_command command="python /mnt/c/Temp/MD-WBS-Tools/scripts/reset_session_state.py --target_path /mnt/c/Temp/MD-WBS-Tools/.gemini_session_state.json" description="保存されたセッション状態ファイルを削除します。"
```

これらのスクリプトを手動で活用することで、セッションの状態をある程度管理し、作業の中断・再開時のコンテキスト把握に役立てることができます。

## PowerShell 7.5.1以上で PowerShellスクリプトを実行する方法

1.  **PowerShell 7.5.1以上をインストールする。**

    *   Windows PowerShell (pwsh.exe) を使用する。

2.  **スクリプトを実行する。**

    *   PowerShellコンソール (pwsh.exe) で、以下のコマンドを実行する。

        ```powershell
        pwsh -File "<スクリプトのパス>" -<`パラメータ`名> "<`パラメータ`の値>"
        ```

        *   `<スクリプトのパス>`: 実行するPowerShellスクリプトの絶対パス。
        *   `<パラメータ名>`: スクリプトに渡す`パラメータ`の名前。
        *   `<パラメータの値>`: `パラメータ`に渡す値。

    *   **WSL 環境から実行する場合:**
        WSL (Linux) 環境からWindows上のPowerShell Core (pwsh.exe) スクリプトを実行するには、`cmd.exe /c` を介し、**Windows 形式のパス**を使用する必要があります。パスは `C:\...` の形式で指定し、パス全体を囲む二重引用符は二重に (`""C:\...""`) してください。

        ```bash
cmd.exe /c "pwsh -File ""<Windows形式のスクリプトのパス>"" -<`パラメータ`名> ""<Windows形式の`パラメータ`の値>"" "
        ```
        **注意:** `/mnt/c/...` の形式は使用できません。

    *   例（WSL環境からcmd.exe経由で実行する場合）：

        ```bash
cmd.exe /c "pwsh -File ""C:\Temp\MD-WBS-Tools\src\powershell\Convert-CsvToSimpleMdWbs.ps1"" -InputCsvPath ""C:\Temp\MD-WBS-Tools\test_outputs\numbering\numbered_wbs.csv"" "
        ```

    *   例（PowerShellコンソールから直接実行する場合）：

        ```powershell
pwsh -File "C:\Temp\MD-WBS-Tools\src\powershell\Convert-ExcelToSimpleMdWbs.ps1" -ExcelPath "C:\Temp\MD-WBS-Tools\samples\excel_examples\simple-markdown-wbs-gantt-sample.xlsx" -OutputPath "C:\Temp\MD-WBS-Tools\test_output.md"
        ```

3.  **UNC パスに関する注意点**


    *   WSL環境からWindowsのファイルにアクセスする場合、パスの形式に注意する。
    *   UNCパス (`\\wsl.localhost\...`) はPowerShellでサポートされない場合があるため、Windows側のパス (`C:\...`) を使用する。


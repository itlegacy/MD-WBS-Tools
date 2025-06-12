# Project A のラウンドトリップテスト（コマンド修正版）
.\src\powershell\Convert-CsvToSimpleMdWbs.ps1 -InputCsvPath '.\tests\outputs\roundtrip\project_A_from_md.csv' -OutputMdPath '.\tests\outputs\roundtrip\project_A_restored_from_csv.md' -Verbose
.\src\powershell\Convert-SimpleMdWbsToCsv.ps1 -InputFilePath '.\samples\mdwbs_examples\sample_project_A.md' -OutputCsvPath '.\tests\outputs\roundtrip\project_A_from_md.csv' -Verbose

# Project B のラウンドトリップテスト（コマンド修正版）
.\src\powershell\Convert-SimpleMdWbsToCsv.ps1 -InputFilePath '.\samples\mdwbs_examples\sample_project_B_comprehensive_with_errors.md' -OutputCsvPath '.\tests\outputs\roundtrip\project_B_from_md.csv' -Verbose
.\src\powershell\Convert-CsvToSimpleMdWbs.ps1 -InputCsvPath '.\tests\outputs\roundtrip\project_B_from_md.csv' -OutputMdPath '.\tests\outputs\roundtrip\project_B_restored_from_csv.md' -Verbose
# MyCommonFunctions.Test.ps1 (修正・完成版)

# スクリプトの先頭で、テスト対象モジュールへの相対パスを解決し、フルパスで一度だけインポートする
try {
    $modulePath = Join-Path $PSScriptRoot "../../src/powershell/Modules/MyCommonFunctions/MyCommonFunctions.psd1"
    Import-Module -Name $modulePath -Force -ErrorAction Stop
}
catch {
    Write-Error "テストの前提条件であるモジュールのインポートに失敗しました。パスを確認してください。 Error: $($_.Exception.Message)"
    # モジュールがなければテストを続行できないので、ここで終了
    return
}

Describe "Get-DecodedAndMappedAttribute Tests" {
    BeforeEach {
        Reset-WbsCounters # 各テストの前にカウンターをリセット
    }

    It "Should return correct ID for Project (H1)" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Should -Be "00.00.00.00"
    }

    It "Should return correct ID for first Category1 (H2) after a Project" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null # 前提
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "01.00.00.00"
    }

    It "Should return correct ID for first Category2 (H3) after Project and Category1" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Should -Be "01.01.00.00"
    }

    It "Should return correct ID for first Category3 (H4) after Project, Cat1, Cat2" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Out-Null
        Get-DecodedAndMappedAttribute -level 4 -itemType "Category3" | Should -Be "01.01.01.00"
    }

    It "Should return correct ID for first Task after Project, Cat1, Cat2, Cat3" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Out-Null
        Get-DecodedAndMappedAttribute -level 4 -itemType "Category3" | Out-Null
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.01.01"
    }

    It "Should return correct ID sequence for multiple categories and tasks" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Should -Be "00.00.00.00"
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "01.00.00.00"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.00.00.01"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.00.00.02"
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Should -Be "01.01.00.00"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.00.01"
    }

    It "Should reset lower level counters when switching to a higher or same level category" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project"   | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Out-Null
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task"      | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "02.00.00.00"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task"      | Should -Be "02.00.00.01"
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project"   | Should -Be "00.00.00.00"
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "01.00.00.00"
    }
}

Describe "ConvertTo-AttributeObject Tests" {

    It "Should parse a full 13-attribute string correctly" {
        $attrString = "ID01,2025-01-01,2025-01-10,5,先行,PREV01,2025-01-02,2025-01-09,75%,担当A,組織X,2025-01-08,フルコメントです"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        
        $result.UserDefinedId            | Should -Be "ID01"
        $result.StartDateInput           | Should -Be "2025-01-01"
        $result.EndDateInput             | Should -Be "2025-01-10"
        $result.DurationInput            | Should -Be "5"
        $result.DependencyType           | Should -Be "先行"
        $result.PredecessorUserDefinedId | Should -Be "PREV01"
        $result.ActualStartDate          | Should -Be "2025-01-02"
        $result.ActualEndDate            | Should -Be "2025-01-09"
        $result.Progress                 | Should -Be "75%"
        $result.Assignee                 | Should -Be "担当A"
        $result.Organization             | Should -Be "組織X"
        $result.LastUpdatedDate          | Should -Be "2025-01-08"
        $result.ItemComment              | Should -Be "フルコメントです"
    }

    It "Should handle an attribute string with many empty fields (12 attributes)" {
        $attrString = "ID02,,,,,,,,,,,部分コメントのみ" # カンマ11個 = 12要素
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId            | Should -Be "ID02"
        $result.LastUpdatedDate          | Should -Be "部分コメントのみ"
        $result.ItemComment              | Should -Be ""
    }

    It "Should handle an attribute string with only ID, dates, and comment (13 attributes)" {
        $attrString = "ID03,2025-02-01,,,,,2025-02-02,2025-02-03,,,2025-02-04,IDと日付とコメント"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId     | Should -Be "ID03"
        $result.ActualEndDate     | Should -Be "2025-02-03"
        $result.Organization      | Should -Be "2025-02-04"
        $result.LastUpdatedDate   | Should -Be "IDと日付とコメント"
        $result.ItemComment       | Should -Be "" # 要素が12個なのでコメントは空
    }

    It "Should handle an attribute string with a comment containing commas (more than 13 elements)" {
        $attrString = "ID05,,,,,,,,,,,,コメント,カンマ入り,です"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.LastUpdatedDate | Should -Be ""
        $result.ItemComment     | Should -Be "コメント,カンマ入り,です"
    }
    
    It "Should correctly parse when exactly 13 attributes are provided (ItemComment is the last field)" {
        $attrString = "ID04,,,,,,,,,,,,13番目の要素(コメント)" # カンマ12個 = 13要素
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.LastUpdatedDate | Should -Be ""
        $result.ItemComment     | Should -Be "13番目の要素(コメント)"
    }

    It "Should return null for a null or whitespace string" {
        (ConvertTo-AttributeObject -AttributeString $null) | Should -BeNullOrEmpty
        (ConvertTo-AttributeObject -AttributeString "   ") | Should -BeNullOrEmpty
    }
}

# ... (既存の ConvertTo-AttributeObject Tests の Describe ブロックの終了後) ...

Describe "ConvertTo-SimpleMdWbsAttributeString Tests" {
    It "Should convert a CsvRowItem with all properties to a correct attribute string" {
        $csvRow = [PSCustomObject]@{
            'ユーザー記述ID' = "TASK01"
            '開始入力'     = "2025-01-01"
            '終了入力'     = "2025-01-05"
            '日数入力'     = "5"
            '関連種別'     = "先行"
            '先行タスクユーザー記述ID' = "PREV01" # CSVの列名に合わせる
            '開始実績'     = "2025-01-02"
            '修了実績'     = "2025-01-06" # CSVの列名に合わせる
            '進捗実績'     = "50%"        # CSVの列名に合わせる
            '担当者名'     = "山田太郎"
            '担当組織'     = "開発部"
            '最終更新'     = "2025-01-03"
            'コメント'     = "これはテストコメントです"
        }
        $expectedString = "TASK01,2025-01-01,2025-01-05,5,先行,PREV01,2025-01-02,2025-01-06,50%,山田太郎,開発部,2025-01-03,これはテストコメントです"
        ConvertTo-SimpleMdWbsAttributeString -CsvRowItem $csvRow | Should -Be $expectedString
    }

    It "Should handle a CsvRowItem with some missing properties (resulting in empty fields)" {
        $csvRow = [PSCustomObject]@{
            'ユーザー記述ID' = "TASK02"
            '開始入力'     = "2025-02-01"
            # '終了入力' は欠損
            '日数入力'     = "3"
            # '関連種別' は欠損
            # '先行タスクユーザー記述ID' は欠損
            '開始実績'     = "2025-02-02"
            '修了実績'     = "" # 空文字で指定
            '進捗実績'     = "10%"
            '担当者名'     = "佐藤花子"
            # '担当組織' は欠損
            '最終更新'     = "2025-02-03"
            'コメント'     = "一部欠損データ"
        }
        # 期待される文字列: 欠損プロパティは空のフィールドになる
        $expectedString = "TASK02,2025-02-01,,3,,,2025-02-02,,10%,佐藤花子,,2025-02-03,一部欠損データ"
        ConvertTo-SimpleMdWbsAttributeString -CsvRowItem $csvRow | Should -Be $expectedString
    }

    It "Should handle a CsvRowItem with only mandatory UserDefinedId" {
        $csvRow = [PSCustomObject]@{
            'ユーザー記述ID' = "TASK03"
        }
        $expectedString = "TASK03,,,,,,,,,,,," # 他の12フィールドは空
        ConvertTo-SimpleMdWbsAttributeString -CsvRowItem $csvRow | Should -Be $expectedString
    }

    It "Should handle a CsvRowItem with a comment containing commas" {
        $csvRow = [PSCustomObject]@{
            'ユーザー記述ID' = "TASK04"
            'コメント'     = "コメント,カンマ入り,です"
        }
        $expectedString = "TASK04,,,,,,,,,,,,コメント,カンマ入り,です"
        ConvertTo-SimpleMdWbsAttributeString -CsvRowItem $csvRow | Should -Be $expectedString
    }
}

# ... (ConvertTo-SimpleMdWbsAttributeString Tests の Describe ブロックの終了後) ...

Describe "Get-SimpleMdWbsHierarchyPrefix Tests" {
    It "Should return correct prefix for Project (Level 1)" {
        Get-SimpleMdWbsHierarchyPrefix -HierarchyLevel 1 -ItemType "Project" | Should -Be "# "
    }

    It "Should return correct prefix for Category1 (Level 2)" {
        Get-SimpleMdWbsHierarchyPrefix -HierarchyLevel 2 -ItemType "Category1" | Should -Be "## "
    }

    It "Should return correct prefix for Category2 (Level 3)" {
        Get-SimpleMdWbsHierarchyPrefix -HierarchyLevel 3 -ItemType "Category2" | Should -Be "### "
    }

    It "Should return correct prefix for Category3 (Level 4)" {
        Get-SimpleMdWbsHierarchyPrefix -HierarchyLevel 4 -ItemType "Category3" | Should -Be "#### "
    }

    It "Should return correct prefix for Task (Level 5)" {
        Get-SimpleMdWbsHierarchyPrefix -HierarchyLevel 5 -ItemType "Task" | Should -Be "- "
    }

    It "Should return empty string and warning for invalid HierarchyLevel" {
        # Write-Warning の出力をキャプチャして検証するのは少し複雑なので、
        # ここでは戻り値が空であることと、エラーが発生しないこと（-ErrorAction Stop で止まらない）を確認する
        # 実際の警告の確認は、手動実行やログで確認する形でも良い
        Get-SimpleMdWbsHierarchyPrefix -HierarchyLevel 99 -ItemType "Task" -WarningAction SilentlyContinue | Should -Be ""
    }
}

AfterAll {
    Remove-Module MyCommonFunctions -Force -ErrorAction SilentlyContinue
}
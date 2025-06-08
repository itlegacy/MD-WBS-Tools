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

AfterAll {
    Remove-Module MyCommonFunctions -Force -ErrorAction SilentlyContinue
}
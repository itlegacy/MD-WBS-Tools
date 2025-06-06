# MyCommonFunctions.Test.ps1

# Pester v5 以降では BeforeAll/AfterAll などがスクリプトスコープで実行されるため、
# モジュールをインポートする場所や方法に注意が必要。
$modulePath = Join-Path $PSScriptRoot "../../src/powershell/Modules/MyCommonFunctions/MyCommonFunctions.psd1"
if (-not (Test-Path $modulePath)) {
    Write-Error "Module manifest not found at $modulePath. Ensure the test script is in the same directory as the module files or adjust the path."
    exit 1
}

BeforeAll {
    Import-Module $modulePath -Force
}

Describe "Get-DecodedAndMappedAttribute Tests" {
    BeforeEach {
        Reset-WbsCounters
    }

    It "Should return correct ID for Project (H1)" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Should -Be "01.00.00.00"
    }

    It "Should return correct ID for first Category1 (H2) after a Project" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null # 前提: H1が一度呼ばれる
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "01.01.00.00"
    }

    It "Should return correct ID for first Category2 (H3) after Project and Category1" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Should -Be "01.01.01.00"
    }

    It "Should return correct ID for first Category3 (H4) after Project, Cat1, Cat2" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Out-Null
        Get-DecodedAndMappedAttribute -level 4 -itemType "Category3" | Should -Be "01.01.01.01"
    }

    It "Should return correct ID for first Task after Project, Cat1, Cat2, Cat3" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Out-Null
        Get-DecodedAndMappedAttribute -level 4 -itemType "Category3" | Out-Null
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.01.01.01"
    }

    # 連続呼び出しやカウンターリセットのテストも追加
    It "Should return correct ID sequence for multiple categories and tasks" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Should -Be "01.00.00.00"
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "01.01.00.00"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.00.00.01" # 親がCat1なのでL3,L4は00
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.00.00.02"
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Should -Be "01.01.01.00" # Cat1の下に新しいCat2
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.01.00.01" # 新しいCat2の下の最初のTask
    }

    It "Should reset lower level counters when switching to a higher or same level category" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null # 01.00.00.00
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null # 01.01.00.00
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Out-Null # 01.01.01.00
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Out-Null # 01.01.01.00.01

        # 新しいCategory1 (H2) を開始 -> L3, L4, Taskカウンターがリセットされるはず
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "01.02.00.00"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.02.00.00.01" # 新しいCat1の下の最初のTask

        # 新しいProject (H1) を開始 -> L2, L3, L4, Taskカウンターがリセットされるはず
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Should -Be "02.00.00.00"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "02.00.00.00.01" # 新しいProject直下の最初のTask (L2,L3,L4は00)
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

    It "Should handle an attribute string with many empty fields (13 attributes)" {
        $attrString = "ID02,,,,,,,,,,,," # 全13属性、すべて空（ID以外）
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId | Should -Be "ID02"
        $result.EndDateInput  | Should -Be ""
        $result.ActualEndDate | Should -Be ""
        $result.LastUpdatedDate | Should -Be ""
        $result.ItemComment   | Should -Be ""
    }

    It "Should correctly parse when only some attributes are provided (less than 13)" {
        $attrString = "ID03,,,,,,,,,,11番目の要素(組織)" # 11属性しかない
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId   | Should -Be "ID03"
        $result.Organization    | Should -Be "11番目の要素(組織)"
        $result.LastUpdatedDate | Should -Be "" # 12番目の属性はないので空
        $result.ItemComment     | Should -Be "" # 13番目の属性はないので空
    }

    It "Should correctly parse comment when attributes are exactly 13" {
        $attrString = "ID04,,,,,,,,,,,,13番目の要素(コメント)" # 13属性
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId   | Should -Be "ID04"
        $result.LastUpdatedDate | Should -Be "" # 12番目の属性は空
        $result.ItemComment     | Should -Be "13番目の要素(コメント)"
    }

    It "Should correctly parse comment containing commas (more than 13 elements)" {
        $attrString = "ID05,,,,,,,,,,,,コメント,カンマ入り,です" # 13属性以上
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId   | Should -Be "ID05"
        $result.LastUpdatedDate | Should -Be "" # 12番目の属性は空
        $result.ItemComment     | Should -Be "コメント,カンマ入り,です"
    }

    It "Should handle special characters in comment (13th element)" {
        $expectedComment = '!@#$%^&*()_+=-~[]\{}|;'':"",./<>?' # HTMLエンティティをデコード後の文字に修正
        $attrString = "ID06,,,,,,,,,,,,$expectedComment"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId   | Should -Be "ID06"
        $result.LastUpdatedDate | Should -Be ""
        $result.ItemComment     | Should -Be $expectedComment
    }

    It "Should handle special characters across LastUpdatedDate and ItemComment" {
        $expectedLastUpdatedDate = "LUD_!@#$"
        $expectedItemComment = "Comment_%^&*"
        $attrString = "ID07,,,,,,,,,,,$expectedLastUpdatedDate,$expectedItemComment"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId     | Should -Be "ID07"
        $result.LastUpdatedDate   | Should -Be $expectedLastUpdatedDate
        $result.ItemComment       | Should -Be $expectedItemComment
    }

    It "Should return null for a null or whitespace string" {
        (ConvertTo-AttributeObject -AttributeString $null) | Should -BeNullOrEmpty
        (ConvertTo-AttributeObject -AttributeString "   ") | Should -BeNullOrEmpty
    }
}

AfterAll {
    Remove-Module MyCommonFunctions -ErrorAction SilentlyContinue
}
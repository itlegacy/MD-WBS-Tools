# MyCommonFunctions.Test.ps1

# Pester v5 以降では BeforeAll/AfterAll などがスクリプトスコープで実行されるため、
# モジュールをインポートする場所や方法に注意が必要。
# ここでは、各Describeブロックの前にモジュールをインポートするアプローチを取る。

$modulePath = Join-Path $PSScriptRoot "MyCommonFunctions.psd1"
if (-not (Test-Path $modulePath)) {
    Write-Error "Module manifest not found at $modulePath. Ensure the test script is in the same directory as the module files or adjust the path."
    exit 1
}

BeforeAll {
    Import-Module $modulePath -Force
}

Describe "Get-DecodedAndMappedAttribute Tests" {
    BeforeEach {
        Reset-WbsCounters # 各テストの前にカウンターをリセット
    }

    It "Should generate correct ID for Project (H1)" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Should -Be "00.00.00.00"
        # Calling H1 again should still return 00.00.00.00 and reset counters for sub-levels
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null # Call some lower level to change counters
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Should -Be "00.00.00.00" # Should reset and return project ID
    }

    It "Should generate correct ID for Category1 (H2)" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null # Establishes Project context (00.00.00.00)
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "01.00.00.00"
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "02.00.00.00" # Second H2 under the same project
    }

    It "Should return correct ID for first Category2 (H3) after Project and Category1" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null # -> 01.00.00.00
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Should -Be "01.01.00.00"
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Should -Be "01.02.00.00" # Second H3 under the first H2
    }

    It "Should return correct ID for first Category3 (H4) after Project, Cat1, Cat2" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null # -> 01.00.00.00
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Out-Null # -> 01.01.00.00
        Get-DecodedAndMappedAttribute -level 4 -itemType "Category3" | Should -Be "01.01.01.00"
        Get-DecodedAndMappedAttribute -level 4 -itemType "Category3" | Should -Be "01.01.02.00" # Second H4 under the first H3
    }

    It "Should return correct ID for first Task after Project, Cat1, Cat2, Cat3" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null # -> 01.00.00.00
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Out-Null # -> 01.01.00.00
        Get-DecodedAndMappedAttribute -level 4 -itemType "Category3" | Out-Null # -> 01.01.01.00
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.01.01"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.01.02" # Second Task under the first H4
    }

    # 連続呼び出しやカウンターリセットのテストも追加
    It "Should return correct ID sequence for multiple categories and tasks" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Should -Be "00.00.00.00"
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "01.00.00.00"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.00.00.01" # Task under H2 (L3,L4 are "00")
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.00.00.02"
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Should -Be "01.01.00.00" # New H3 under the first H2
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.00.01" # First Task under this new H3
    }

    It "Should reset lower level counters when switching to a higher or same level category" {
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null # 00.00.00.00
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null # 01.00.00.00
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Out-Null # 01.01.00.00
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Out-Null # 01.01.00.01

        # New Category1 (H2) starts -> L3, L4, Task counters reset
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "02.00.00.00"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "02.00.00.01" # First Task under this new H2

        # New Project (H1) starts -> L2, L3, L4, Task counters reset
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Should -Be "00.00.00.00"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "00.00.00.01" # First Task directly under new Project (L2,L3,L4 are "00")
    }
}

Describe "ConvertTo-AttributeObject Tests" {

    It "Should parse a full 13-attribute string correctly" {
        $attrString = "ID01,2025-01-01,2025-01-10,5,先行,PREV01,2025-01-02,2025-01-09,75%,担当A,組織X,2025-01-08,フルコメントです"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        
        $result.UserDefinedId            | Should Be "ID01"
        $result.StartDateInput           | Should Be "2025-01-01"
        $result.EndDateInput             | Should Be "2025-01-10"
        $result.DurationInput            | Should Be "5"
        $result.DependencyType           | Should Be "先行"
        $result.PredecessorUserDefinedId | Should Be "PREV01"
        $result.ActualStartDate          | Should Be "2025-01-02"
        $result.ActualEndDate            | Should Be "2025-01-09"
        $result.Progress                 | Should Be "75%"
        $result.Assignee                 | Should Be "担当A"
        $result.Organization             | Should Be "組織X"
        $result.LastUpdatedDate          | Should Be "2025-01-08"
        $result.ItemComment              | Should Be "フルコメントです"
    }

    It "Should handle an attribute string with many empty fields" {
        $attrString = "ID02,,,,,,,,,,,," # 全13属性、すべて空（ID以外）
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        
        $result.UserDefinedId | Should Be "ID02"
        $result.EndDateInput  | Should Be ""
        $result.ActualEndDate | Should Be ""
        $result.LastUpdatedDate | Should Be ""
        $result.ItemComment   | Should Be ""
    }

    It "Should correctly parse comment when attributes are less than 13" {
        $attrString = "ID03,,,,,,,,,,11番目の要素(組織)" # 11属性しかない
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        
        $result.Organization   | Should Be "11番目の要素(組織)"
        $result.LastUpdatedDate| Should Be "" # 12番目の属性はないので空
        $result.ItemComment    | Should Be "" # 13番目の属性はないので空
    }

    It "Should correctly parse comment when attributes are exactly 13" {
        $attrString = "ID04,,,,,,,,,,,,13番目の要素(コメント)" # 13属性
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        
        $result.LastUpdatedDate | Should Be "" # 12番目の属性は空
        $result.ItemComment     | Should Be "13番目の要素(コメント)"
    }

    It "Should correctly parse comment containing commas" {
        $attrString = "ID05,,,,,,,,,,,,コメント,カンマ入り,です" # 13属性以上
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        
        $result.LastUpdatedDate | Should Be "" # 12番目の属性は空
        $result.ItemComment     | Should Be "コメント,カンマ入り,です"
    }

    It "Should handle special characters in comment" {
        $expectedComment = '!@#$%^&*()_+=-~[]\{}|;'':"",./&lt;&gt;?'
        $attrString = "ID06,,,,,,,,,,,,$expectedComment"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        
        $result.ItemComment | Should Be $expectedComment
    }

    It "Should return null for a null or whitespace string" {
        (ConvertTo-AttributeObject -AttributeString $null) | Should BeNullOrEmpty
        (ConvertTo-AttributeObject -AttributeString "   ") | Should BeNullOrEmpty
    }

    It "Should correctly parse when exactly 12 attributes are provided (ItemComment should be empty)" {
        $attrString = "ID_12_ATTR,SD,ED,DUR,DT,PID,ASD,AED,PROG,ASSIGNEE,ORG,LUD_VALUE_12"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId            | Should -Be "ID_12_ATTR"
        $result.StartDateInput           | Should -Be "SD"
        $result.EndDateInput             | Should -Be "ED"
        $result.DurationInput            | Should -Be "DUR"
        $result.DependencyType           | Should -Be "DT"
        $result.PredecessorUserDefinedId | Should -Be "PID"
        $result.ActualStartDate          | Should -Be "ASD"
        $result.ActualEndDate            | Should -Be "AED"
        $result.Progress                 | Should -Be "PROG"
        $result.Assignee                 | Should -Be "ASSIGNEE"
        $result.Organization             | Should -Be "ORG"
        $result.LastUpdatedDate          | Should -Be "LUD_VALUE_12"
        $result.ItemComment              | Should -Be ""
    }

    It "Should correctly parse when 13 attributes are provided and the 13th (ItemComment) is an empty field" {
        $attrString = "ID_13_EMPTY_COMMENT,SD,ED,DUR,DT,PID,ASD,AED,PROG,ASSIGNEE,ORG,LUD_VALUE_13," # Trailing comma
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId            | Should -Be "ID_13_EMPTY_COMMENT"
        $result.LastUpdatedDate          | Should -Be "LUD_VALUE_13"
        $result.ItemComment              | Should -Be ""
    }

    It "Should correctly parse when 10 attributes are provided with some empty fields" {
        $attrString = "ID_10_FIELDS,SD_VAL,,DUR_VAL,,,,ASD_VAL,,,ASSIGNEE_VAL" # 10 fields total
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId            | Should -Be "ID_10_FIELDS"
        $result.StartDateInput           | Should -Be "SD_VAL"
        $result.EndDateInput             | Should -Be ""
        $result.DurationInput            | Should -Be "DUR_VAL"
        $result.DependencyType           | Should -Be ""
        $result.PredecessorUserDefinedId | Should -Be ""
        $result.ActualStartDate          | Should -Be "ASD_VAL"
        $result.ActualEndDate            | Should -Be ""
        $result.Progress                 | Should -Be ""
        $result.Assignee                 | Should -Be "ASSIGNEE_VAL"
        $result.Organization             | Should -Be ""
        $result.LastUpdatedDate          | Should -Be ""
        $result.ItemComment              | Should -Be ""
    }
}

AfterAll {
    Remove-Module MyCommonFunctions -ErrorAction SilentlyContinue
}
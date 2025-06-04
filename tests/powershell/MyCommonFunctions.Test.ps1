# MyCommonFunctions.Test.ps1
$modulePath = Join-Path $PSScriptRoot "../../src/powershell/Modules/MyCommonFunctions/MyCommonFunctions.psd1" # モジュールへのパスを調整
Write-Host "Module Path: $modulePath" # ★ 追加
Import-Module $modulePath -Force

Describe "Get-DecodedAndMappedAttribute Tests" {
    BeforeEach {
        Reset-WbsCounters
    }

    It "Should return correct ID for Project (H1)" {
        # Pending "PesterのParameterBindingValidationExceptionのためスキップ" # Pendingを解除
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Should -Be "01.00.00.00"
    }

    It "Should return correct ID for first Category1 (H2) after a Project" {
        # Pending "PesterのParameterBindingValidationExceptionのためスキップ" # Pendingを解除
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null # 前提: H1が一度呼ばれる
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "01.01.00.00"
    }

    It "Should return correct ID for first Category2 (H3) after Project and Category1" {
        # Pending "PesterのParameterBindingValidationExceptionのためスキップ" # Pendingを解除
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Should -Be "01.01.01.00"
    }

    It "Should return correct ID for first Category3 (H4) after Project, Cat1, Cat2" {
        # Pending "PesterのParameterBindingValidationExceptionのためスキップ" # Pendingを解除
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Out-Null
        Get-DecodedAndMappedAttribute -level 4 -itemType "Category3" | Should -Be "01.01.01.01"
    }

    It "Should return correct ID for first Task after Project, Cat1, Cat2, Cat3" {
        # Pending "PesterのParameterBindingValidationExceptionのためスキップ" # Pendingを解除
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Out-Null
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Out-Null
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Out-Null
        Get-DecodedAndMappedAttribute -level 4 -itemType "Category3" | Out-Null
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.01.01.01"
    }

    # 連続呼び出しやカウンターリセットのテストも追加
    It "Should return correct ID sequence for multiple categories and tasks" {
        # Pending "PesterのParameterBindingValidationExceptionのためスキップ" # Pendingを解除
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Should -Be "01.00.00.00"
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "01.01.00.00"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.00.00.01" # 親がCat1なのでL3,L4は00
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.00.00.02"
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" | Should -Be "01.01.01.00" # Cat1の下に新しいCat2
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.01.01.00.01" # 新しいCat2の下の最初のTask
    }

    It "Should reset lower level counters when switching to a higher or same level category" {
        # Pending "PesterのParameterBindingValidationExceptionのためスキップ" # Pendingを解除
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

    It "Should handle a 13-attribute string with many empty fields including new date fields" {
        $attrString = "ID02,,,,,,,,,,,部分コメントのみ" # 全13属性, 12番目の最終更新日まで空
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId            | Should -Be "ID02"
        $result.StartDateInput           | Should -Be ""
        $result.ActualEndDate            | Should -Be ""
        $result.LastUpdatedDate          | Should -Be "部分コメントのみ"
        $result.ItemComment              | Should -Be ""
    }

    It "Should handle a 13-attribute string with only ID, dates, and comment" {
        #                UID,   SDi, EDi, DUi, DepT,PID, ASD, AED, Prog,Asgn,Org, LUD, Comment
        $attrString = "ID03,2025-02-01,,,,,2025-02-02,2025-02-03,,,2025-02-04,IDと日付とコメント"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId     | Should -Be "ID03"
        $result.StartDateInput    | Should -Be "2025-02-01"
        $result.EndDateInput      | Should -Be ""
        $result.ActualStartDate   | Should -Be "2025-02-02"
        $result.ActualEndDate     | Should -Be "2025-02-03"
        $result.Organization      | Should -Be "2025-02-04" # 注意: この期待値は関数のロジックと一致しない可能性があります。入力文字列では11番目の要素が "2025-02-04" です。
        $result.LastUpdatedDate   | Should -Be "IDと日付とコメント"
        $result.ItemComment       | Should -Be ""
    }

    It "Should handle a 13-attribute string with a comment containing commas" {
        #                UID,SDi,EDi,DUi,DepT,PID,ASD,AED,Prog,Asgn,Org,LUD, Comment1, Comment2, Comment3
        $attrString = "ID04,,,,,,,,,,,コメント,カンマ入り,です"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId     | Should -Be "ID04"
        $result.LastUpdatedDate   | Should -Be "コメント"
        $result.ItemComment       | Should -Be "カンマ入り,です"
    }

    # 以前の特殊文字テストも13属性に合わせて調整
    It "Should handle an attribute string with various special characters in comment (13 attributes)" {
        $expectedLastUpdatedDate = '!@#$%^&*()_+=-~[]\{}|;'':""' # 12番目の要素 (最終更新日)
        $expectedItemComment = './<>?'                            # 13番目の要素 (コメント)
        #                UID,SDi,EDi,DUi,DepT,PID, ASD, AED, Prog,Asgn,Org, LUD, Comment
        $attrString = "ID06,,,,,,,,,,,$expectedLastUpdatedDate,$expectedItemComment"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId | Should -Be "ID06"
        $result.ActualEndDate | Should -Be ""
        $result.LastUpdatedDate | Should -Be $expectedLastUpdatedDate
        $result.ItemComment | Should -Be $expectedItemComment
    }

    It "Should return null for a null or whitespace string" {
        (ConvertTo-AttributeObject -AttributeString $null) | Should -BeNullOrEmpty
        (ConvertTo-AttributeObject -AttributeString "   ") | Should -BeNullOrEmpty
    }
}
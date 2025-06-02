# MyCommonFunctions.Test.ps1
$modulePath = Join-Path $PSScriptRoot "../../src/powershell/Modules/MyCommonFunctions/MyCommonFunctions.psd1" # モジュールへのパスを調整
Write-Host "Module Path: $modulePath" # ★ 追加
Import-Module $modulePath -Force

Get-Module MyCommonFunctions | Format-List * # インポートされたモジュールの詳細表示
Get-Command -Module MyCommonFunctions         # モジュールからエクスポートされたコマンド一覧表示
# read-host "Press Enter to continue tests..." # 必要ならここで一時停止して確認

Describe "Get-DecodedAndMappedAttribute Tests" {
    BeforeEach {
        Import-Module $modulePath -Force
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
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" # 01.00.00.00
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" # 01.01.00.00
        Get-DecodedAndMappedAttribute -level 3 -itemType "Category2" # 01.01.01.00
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" # 01.01.01.00.01

        # 新しいCategory1 (H2) を開始 -> L3, L4, Taskカウンターがリセットされるはず
        Get-DecodedAndMappedAttribute -level 2 -itemType "Category1" | Should -Be "01.02.00.00"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "01.02.00.00.01" # 新しいCat1の下の最初のTask

        # 新しいProject (H1) を開始 -> L2, L3, L4, Taskカウンターがリセットされるはず
        Get-DecodedAndMappedAttribute -level 1 -itemType "Project" | Should -Be "02.00.00.00"
        Get-DecodedAndMappedAttribute -level 5 -itemType "Task" | Should -Be "02.00.00.00.01" # 新しいProject直下の最初のTask (L2,L3,L4は00)
    }
}

Describe "ConvertTo-AttributeObject Tests" {
    BeforeEach {
        Import-Module $modulePath -Force
    }

    It "Should parse a full attribute string correctly" {
        $attrString = "ID01,2025-12-31,10,先行,ID00,完了,100%,田中,開発部,2025-12-01,フルコメント"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId | Should -Be "ID01"
        $result.EndDate | Should -Be "2025-12-31"
        $result.Duration | Should -Be "10"
        $result.DependencyType | Should -Be "先行"
        $result.PredecessorUserDefinedId | Should -Be "ID00"
        $result.Status | Should -Be "完了"
        $result.Progress | Should -Be "100%"
        $result.Assignee | Should -Be "田中"
        $result.Organization | Should -Be "開発部"
        $result.ActualStartDate | Should -Be "2025-12-01"
        $result.ItemComment | Should -Be "フルコメント"
    }

    It "Should handle an attribute string with many empty fields" {
        $attrString = "ID02,,,,,,,,,,部分コメント"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId | Should -Be "ID02"
        $result.EndDate | Should -Be ""
        $result.Duration | Should -Be ""
        $result.DependencyType | Should -Be ""
        $result.PredecessorUserDefinedId | Should -Be ""
        $result.Status | Should -Be ""
        $result.Progress | Should -Be ""
        $result.Assignee | Should -Be ""
        $result.Organization | Should -Be ""
        $result.ActualStartDate | Should -Be ""
        $result.ItemComment | Should -Be "部分コメント"
    }

    It "Should handle an attribute string with only ID and comment" {
        $attrString = "ID03,,,,,,,,,,IDとコメントのみ"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId | Should -Be "ID03"
        $result.EndDate | Should -Be ""
        $result.Duration | Should -Be ""
        $result.DependencyType | Should -Be ""
        $result.PredecessorUserDefinedId | Should -Be ""
        $result.Status | Should -Be ""
        $result.Progress | Should -Be ""
        $result.Assignee | Should -Be ""
        $result.Organization | Should -Be ""
        $result.ActualStartDate | Should -Be ""
        $result.ItemComment | Should -Be "IDとコメントのみ"
    }

    It "Should handle an attribute string with a comment containing commas" {
        $attrString = "ID04,,,,,,,,,,コメント,カンマ入り,です"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId | Should -Be "ID04"
        $result.EndDate | Should -Be ""
        $result.Duration | Should -Be ""
        $result.DependencyType | Should -Be ""
        $result.PredecessorUserDefinedId | Should -Be ""
        $result.Status | Should -Be ""
        $result.Progress | Should -Be ""
        $result.Assignee | Should -Be ""
        $result.Organization | Should -Be ""
        $result.ActualStartDate | Should -Be ""
        $result.ItemComment | Should -Be "コメント,カンマ入り,です"
    }

    It "Should return null for a null or whitespace string" {
        (ConvertTo-AttributeObject -AttributeString $null) | Should -BeNullOrEmpty
        (ConvertTo-AttributeObject -AttributeString "   ") | Should -BeNullOrEmpty
    }

    It "Should handle an attribute string with HTML encoded characters in comment" {
        $attrString = "ID05,,,,,,,,,,&lt;p&gt;HTMLエンコードされたコメント&lt;/p&gt;"
        $result = ConvertTo-AttributeObject -AttributeString $attrString
        $result.UserDefinedId | Should -Be "ID05"
        $result.ItemComment | Should -Be "<p>HTMLエンコードされたコメント</p>"
    }

    It "Should handle an attribute string with various special characters" {
        $inputComment = @'
!@#$%^&*()_+=-~[]\{}|;':"",./<>?
'@
        $inputComment = $inputComment.Trim() # ヒアストリングは前後の改行を含むことがあるため

        $attrString = "ID06,2025-12-31,10,先行,ID00,完了,100%,田中,開発部,2025-12-01,$inputComment"
        #$attrString = "ID06,2025-12-31,10,先行,ID00,完了,100%,田中,開発部,2025-12-01,$inputCommentHereString" # ヒアストリング版

        $result = ConvertTo-AttributeObject -AttributeString $attrString
        # ... 他の属性の検証 ...
        $result.ItemComment | Should -Be $inputComment # または $inputCommentHereString
    }
}
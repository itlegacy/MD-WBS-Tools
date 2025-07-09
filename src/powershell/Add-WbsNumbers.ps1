<#
.SYNOPSIS
    WBSのCSVファイルに、階層に基づいたWBS番号を付与します。
.DESCRIPTION
    (Version 1.1.0: Corrected initialization and reset logic)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$InputCsvPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputCsvPath
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"
    Write-Verbose "Starting script: $($MyInvocation.MyCommand.Name)"
}

process {
    try {
        $csvData = Import-Csv -Path $InputCsvPath -Encoding UTF8
        if ($null -eq $csvData) {
            Write-Warning "CSV file is empty."
            return
        }

        $outputObjects = [System.Collections.Generic.List[object]]::new()
        
        # [最重要修正] ユーザー指示通り、カウンターの初期値を設定
        $counters = @(1, 1, 1, 0) # H1, H2, H3 は1から。Task(H4)は0から。
        
        $isFirstRow = $true

        foreach ($row in $csvData) {
            $currentLevel = ""
            if (-not [string]::IsNullOrEmpty($row.'大分類')) {
                if ($isFirstRow) { $currentLevel = "H1" } else { $currentLevel = "H2" }
            }
            elseif (-not [string]::IsNullOrEmpty($row.'中分類')) { $currentLevel = "H3" }
            elseif (-not [string]::IsNullOrEmpty($row.'小分類')) { $currentLevel = "H4" }
            elseif (-not [string]::IsNullOrEmpty($row.'タスクアイテム')) { $currentLevel = "Task" }
            else { continue }
            $isFirstRow = $false

            # [最重要修正]
            # 1. 現在のレベルのカウンターをインクリメントする
            switch ($currentLevel) {
                "H1"   { $counters[0]++; $counters[1]=1; $counters[2]=1; $counters[3]=0 }
                "H2"   { $counters[1]++; $counters[2]=1; $counters[3]=0 }
                "H3"   { $counters[2]++; $counters[3]=0 }
                "H4"   { $counters[3]++ }
                "Task" { $counters[3]++ }
            }
            
            # 2. 更新されたカウンターを使って、現在の行のWBS番号を生成する
            $wbsNumber = "{0:D2}.{1:D2}.{2:D2}.{3:D3}" -f $counters[0], $counters[1], $counters[2], $counters[3]

            $row | Add-Member -MemberType NoteProperty -Name 'WBS番号' -Value $wbsNumber -Force
            $outputObjects.Add($row)
            
            Write-Verbose "Assigned number [$wbsNumber] to '$($row.'大分類')$($row.'中分類')$($row.'小分類')$($row.'タスクアイテム')'"
        }

        $outputObjects | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8BOM
        
        Write-Host "Successfully added WBS numbers and saved to: $OutputCsvPath" -ForegroundColor Green
    }
    catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
    }
}

end {
    Write-Verbose "Script finished."
}
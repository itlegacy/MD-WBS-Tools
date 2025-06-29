param(
    [string]$TaskDescription,
    [string]$CurrentPlan,
    [string[]]$CompletedSteps,
    [string[]]$PendingSteps,
    [hashtable]$LastToolCall,
    [string[]]$ContextFiles,
    [string]$SessionStateFilePath
)

# JSONオブジェクトの作成
$sessionState = @{
    task_description = $TaskDescription
    current_plan = $CurrentPlan
    completed_steps = $CompletedSteps
    pending_steps = $PendingSteps
    last_tool_call = $LastToolCall
    context_files = $ContextFiles
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ") # ISO 8601形式
}

# JSON形式に変換してファイルに書き出し
$sessionState | ConvertTo-Json -Depth 100 | Set-Content -Path $SessionStateFilePath -Encoding UTF8 -Force

Write-Host "Session state saved to: $SessionStateFilePath"

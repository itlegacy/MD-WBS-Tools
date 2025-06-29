param(
    [string]$SessionStateFilePath
)

if (Test-Path -Path $SessionStateFilePath -PathType Leaf) {
    try {
        Remove-Item -Path $SessionStateFilePath -Force
        Write-Host "Session state file removed: $SessionStateFilePath"
    }
    catch {
        Write-Error "Failed to remove session state file: $($_.Exception.Message)"
    }
} else {
    Write-Host "No session state file found at: $SessionStateFilePath"
}

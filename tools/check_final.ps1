$json = Get-Content feeds_final_test.json -Raw | ConvertFrom-Json
Write-Host "Feed count: $($json.Count)"
$json | ForEach-Object { 
    Write-Host "  - $($_.title) | Error: $($_.lastError)"
}
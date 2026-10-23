$json = Get-Content feeds_after_test.json -Raw | ConvertFrom-Json
Write-Host "Feed count: $($json.Count)"
$json | ForEach-Object { Write-Host "  - $($_.title)" }
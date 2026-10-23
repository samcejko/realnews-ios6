$json = Get-Content feeds_original.json -Raw | ConvertFrom-Json
$testFeed = @{
    title = 'Timeout Test Feed'
    feedDescription = 'Test feed for timeout testing'
    category = 'Test'
    siteURL = 'http://10.255.255.1/'
    lastUpdated = 0
    items = @()
    url = 'http://10.255.255.1/feed.xml'
}
$newFeeds = @($testFeed) + $json
$newFeeds | ConvertTo-Json -Depth 10 | Set-Content feeds_with_test.json
Write-Host 'Test feed added locally'
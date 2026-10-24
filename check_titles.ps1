$json = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes('C:\Users\samcejko\Documents\realnews-ios6\feeds_after_105_test.json'))
$regex = [System.Text.RegularExpressions.Regex]::new('"title"\s*:\s*"([^"]*)"')
$matches = $regex.Matches($json)
$count = 0
foreach ($m in $matches) {
    if ($count -lt 15) {
        Write-Host $m.Groups[1].Value
        $count++
    }
}
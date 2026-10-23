Add-Type -AssemblyName System.Drawing
$files = @("packages\rn-1-feeds.png", "packages\rn-8-imageviewer.png", "packages\rn-11-metadata.png", "packages\home-screen.png")
foreach ($f in $files) {
    if (Test-Path $f) {
        $img = [System.Drawing.Image]::FromFile($f)
        Write-Host "$f : $($img.Width)x$($img.Height) $([math]::Round($img.Length/1024,1))KB"
        $img.Dispose()
    } else {
        Write-Host "$f : NOT FOUND"
    }
}
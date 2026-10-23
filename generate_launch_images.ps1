Add-Type -AssemblyName System.Drawing

$sourceIcon = "Resources\iTunesArtwork.png"
$outputDir = "Resources"

if (-not (Test-Path $sourceIcon)) {
    Write-Error "Source icon not found: $sourceIcon"
    exit 1
}

$srcImg = [System.Drawing.Image]::FromFile($sourceIcon)

# App theme colors
$bgColor = [System.Drawing.Color]::FromArgb(26, 26, 28)  # #1a1a1c night theme background
$iconBgColor = [System.Drawing.Color]::FromArgb(238, 120, 24)  # #ee7818 brand orange

# Launch image specifications for iOS 5-10
$specs = @(
    # iPhone
    @{ Name="Default.png";          Width=320;  Height=480;  Scale=1 },
    @{ Name="Default@2x.png";       Width=640;  Height=960;  Scale=2 },
    @{ Name="Default-568h@2x.png";  Width=640;  Height=1136; Scale=2 },
    @{ Name="Default-667h@2x.png";  Width=750;  Height=1334; Scale=2 },
    @{ Name="Default-736h@3x.png";  Width=1242; Height=2208; Scale=3 },
    # iPad
    @{ Name="Default-Portrait.png";         Width=768;  Height=1004; Scale=1 },
    @{ Name="Default-Portrait@2x.png";      Width=1536; Height=2008; Scale=2 },
    @{ Name="Default-Landscape.png";        Width=1024; Height=748;  Scale=1 },
    @{ Name="Default-Landscape@2x.png";     Width=2048; Height=1496; Scale=2 }
)

foreach ($spec in $specs) {
    $bmp = New-Object System.Drawing.Bitmap($spec.Width, $spec.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.Clear($bgColor)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

    # Calculate icon size (roughly 1/4 of screen height, max 200pt)
    $iconSize = [Math]::Min($spec.Height / 4, 200 * $spec.Scale)
    $iconX = ($spec.Width - $iconSize) / 2
    $iconY = ($spec.Height - $iconSize) / 2

    # Draw icon background circle
    $circleRect = New-Object System.Drawing.RectangleF($iconX, $iconY, $iconSize, $iconSize)
    $circlePath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $circlePath.AddEllipse($circleRect)
    $brush = New-Object System.Drawing.SolidBrush($iconBgColor)
    $graphics.FillPath($brush, $circlePath)
    $brush.Dispose()

    # Draw icon image centered in circle
    $padding = $iconSize * 0.15
    $drawRect = New-Object System.Drawing.RectangleF($iconX + $padding, $iconY + $padding, $iconSize - 2*$padding, $iconSize - 2*$padding)
    $graphics.DrawImage($srcImg, $drawRect)

    $graphics.Dispose()

    $outputPath = Join-Path $outputDir $spec.Name
    $bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()

    Write-Host "Created: $($spec.Name) ($($spec.Width)x$($spec.Height))"
}

$srcImg.Dispose()
Write-Host "All launch images generated successfully!"
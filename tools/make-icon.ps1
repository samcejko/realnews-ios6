param(
    [string]$ResourcesDir = "$PSScriptRoot\..\Resources",
    [string]$CydiaRepoDir = "$PSScriptRoot\..\..\cydia-repo",
    [int]$MasterSize = 1024
)

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $ResourcesDir)) {
    New-Item -ItemType Directory -Path $ResourcesDir -Force | Out-Null
}

$bmp = New-Object System.Drawing.Bitmap $MasterSize, $MasterSize, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(255, 255, 175, 75))
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$Size = $MasterSize

# 1. Rounded rectangle path
$radius = [int]($Size * 0.22)
$dia = $radius * 2
$iconPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$iconPath.AddArc(0, 0, $dia, $dia, 180, 90)
$iconPath.AddArc($Size - $dia, 0, $dia, $dia, 270, 90)
$iconPath.AddArc($Size - $dia, $Size - $dia, $dia, $dia, 0, 90)
$iconPath.AddArc(0, $Size - $dia, $dia, $dia, 90, 90)
$iconPath.CloseFigure()

# For iOS 6 app bundle, icons must be fully opaque squares with NO transparent corners.
# SpringBoard automatically masks app icons to rounded rectangles.
# If an app icon has transparent corners, SpringBoard renders black triangles in the corners!

# 2. Background gradient (rich RSS orange aqua style)
$rect = New-Object System.Drawing.Rectangle 0, 0, $Size, $Size
$cTop = [System.Drawing.Color]::FromArgb(255, 255, 165, 50)
$cBot = [System.Drawing.Color]::FromArgb(255, 225, 75, 0)
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush ($rect, $cTop, $cBot, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)

# Add subtle color blend curve
$blend = New-Object System.Drawing.Drawing2D.ColorBlend 4
$blend.Colors = @(
    [System.Drawing.Color]::FromArgb(255, 255, 175, 75),
    [System.Drawing.Color]::FromArgb(255, 250, 115, 5),
    [System.Drawing.Color]::FromArgb(255, 215, 65, 0),
    [System.Drawing.Color]::FromArgb(255, 240, 95, 10)
)
$blend.Positions = @(0.0, 0.46, 0.50, 1.0)
$bgBrush.InterpolationColors = $blend

$g.FillRectangle($bgBrush, $rect)
$bgBrush.Dispose()

# Top rim highlight (like in all user's icons)
$rimBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(160, 255, 255, 255))
$g.FillRectangle($rimBrush, 0, 0, $Size, [int]($Size * 0.006))
$rimBrush.Dispose()

# 2. RSS Signal Waves & Dot
$ox = [int]($Size * 0.22)
$oy = [int]($Size * 0.78)

# Subtle shadow offset
$shadowOffsetY = [int]($Size * 0.018)

function Draw-RSSGlyph($graphics, $offsetX, $offsetY, $brush, $drawCenter) {
    # Dot at bottom-left
    $dotR = [int]($Size * 0.075)
    $graphics.FillEllipse($brush, ($ox + $offsetX - $dotR), ($oy + $offsetY - $dotR), ($dotR * 2), ($dotR * 2))

    # Inner wave
    $r1_in = [int]($Size * 0.23)
    $r1_out = [int]($Size * 0.33)
    $thick1 = $r1_out - $r1_in
    $pen1 = New-Object System.Drawing.Pen ($brush, $thick1)
    $pen1.StartCap = [System.Drawing.Drawing2D.LineCap]::Flat
    $pen1.EndCap = [System.Drawing.Drawing2D.LineCap]::Flat
    $midR1 = ($r1_in + $r1_out) / 2
    $graphics.DrawArc($pen1, [float]($ox + $offsetX - $midR1), [float]($oy + $offsetY - $midR1), [float]($midR1 * 2), [float]($midR1 * 2), 270.0, 90.0)
    $pen1.Dispose()

    # Outer wave
    $r2_in = [int]($Size * 0.43)
    $r2_out = [int]($Size * 0.53)
    $thick2 = $r2_out - $r2_in
    $pen2 = New-Object System.Drawing.Pen ($brush, $thick2)
    $pen2.StartCap = [System.Drawing.Drawing2D.LineCap]::Flat
    $pen2.EndCap = [System.Drawing.Drawing2D.LineCap]::Flat
    $midR2 = ($r2_in + $r2_out) / 2
    $graphics.DrawArc($pen2, [float]($ox + $offsetX - $midR2), [float]($oy + $offsetY - $midR2), [float]($midR2 * 2), [float]($midR2 * 2), 270.0, 90.0)
    $pen2.Dispose()
}

# Draw dropped shadow for depth
$shadowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(65, 80, 20, 0))
Draw-RSSGlyph $g 0 $shadowOffsetY $shadowBrush
$shadowBrush.Dispose()

# Draw main crisp white RSS symbol
$whiteBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
Draw-RSSGlyph $g 0 0 $whiteBrush
$whiteBrush.Dispose()

# 3. Signature iOS 6 Gloss Curve across the top half
$glossPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$glossHeight = [int]($Size * 0.44)
$glossDip = [int]($Size * 0.56)

$glossPath.AddLine(0, 0, $Size, 0)
$glossPath.AddLine($Size, 0, $Size, $glossHeight)
$glossPath.AddBezier($Size, $glossHeight, [int]($Size * 0.77), $glossDip, [int]($Size * 0.23), $glossDip, 0, $glossHeight)
$glossPath.CloseFigure()

$glossRect = New-Object System.Drawing.Rectangle 0, 0, $Size, $glossDip
$glossBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush ($glossRect, [System.Drawing.Color]::FromArgb(115, 255, 255, 255), [System.Drawing.Color]::FromArgb(15, 255, 255, 255), [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
$g.FillPath($glossBrush, $glossPath)
$glossBrush.Dispose()
$glossPath.Dispose()

$g.Dispose()
$iconPath.Dispose()

# 4. Export all iOS icon sizes
$sizes = @{
    "iTunesArtwork.png"    = 1024
    "Icon.png"             = 57
    "Icon@2x.png"          = 114
    "Icon-72.png"          = 72
    "Icon-72@2x.png"       = 144
    "Icon-Small.png"       = 29
    "Icon-Small@2x.png"    = 58
    "Icon-Small-50.png"    = 50
    "Icon-Small-50@2x.png" = 100
    "Icon-60@2x.png"       = 120
    "Icon-60@3x.png"       = 180
    "Icon-76.png"          = 76
    "Icon-76@2x.png"       = 152
    "Icon-83.5@2x.png"     = 167
}

function Resize-And-Save([System.Drawing.Image]$src, [int]$sz, [string]$outPath) {
    $targetBmp = New-Object System.Drawing.Bitmap($sz, $sz, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $tg = [System.Drawing.Graphics]::FromImage($targetBmp)
    $tg.Clear([System.Drawing.Color]::FromArgb(255, 255, 175, 75))
    $tg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $tg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $tg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $tg.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $tg.DrawImage($src, 0, 0, $sz, $sz)
    $tg.Dispose()
    $targetBmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $targetBmp.Dispose()
}

Write-Host "Exporting RealNews icon sizes to $ResourcesDir ..."
foreach ($name in $sizes.Keys) {
    $sz = $sizes[$name]
    $dest = Join-Path $ResourcesDir $name
    Resize-And-Save $bmp $sz $dest
    Write-Host "  -> $name ($sz x $sz)"
}

# Export to cydia-repo if present
$cydiaIconDir = Join-Path $CydiaRepoDir "site\icons"
if (Test-Path $cydiaIconDir) {
    $cydiaIcon = Join-Path $cydiaIconDir "com.samcejko.realnews.png"
    Resize-And-Save $bmp 144 $cydiaIcon
    Write-Host "  -> Exported to Cydia repo: $cydiaIcon (144x144)"
}

$bmp.Dispose()
Write-Host "Done! RealNews icon in signature iOS 6 style created successfully."

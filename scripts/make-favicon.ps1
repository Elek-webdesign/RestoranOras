Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "images\logo-oras.png"
$bmp = New-Object System.Drawing.Bitmap($src)
$bg = [System.Drawing.Color]::White  # matches the source logo's own background exactly

$w = $bmp.Width
$h = $bmp.Height
$threshold = 250

function RowHasContent($bmp, $y, $w, $threshold) {
  for ($x = 0; $x -lt $w; $x++) {
    $p = $bmp.GetPixel($x, $y)
    if ($p.A -gt 10 -and ($p.R -lt $threshold -or $p.G -lt $threshold -or $p.B -lt $threshold)) { return $true }
  }
  return $false
}
function ColHasContent($bmp, $x, $yStart, $yEnd, $threshold) {
  for ($y = $yStart; $y -le $yEnd; $y++) {
    $p = $bmp.GetPixel($x, $y)
    if ($p.A -gt 10 -and ($p.R -lt $threshold -or $p.G -lt $threshold -or $p.B -lt $threshold)) { return $true }
  }
  return $false
}

# Bounding box of the wordmark only: find the first contiguous run of
# content rows (the "ORAS" wordmark) and stop at its end, ignoring
# whatever comes after (the subtitle line, plus any of its ascenders/dots
# that poke up before its own main body starts).
$top = 0
while ($top -lt $h -and -not (RowHasContent $bmp $top $w $threshold)) { $top++ }

$bottom = $top
$y = $top
while ($y -lt $h -and (RowHasContent $bmp $y $w $threshold)) {
  $bottom = $y
  $y++
}

$left = 0
while ($left -lt $w -and -not (ColHasContent $bmp $left $top $bottom $threshold)) { $left++ }
$right = $w - 1
while ($right -gt $left -and -not (ColHasContent $bmp $right $top $bottom $threshold)) { $right-- }

$contentW = $right - $left + 1
$contentH = $bottom - $top + 1

function BuildIcon($bmp, $left, $top, $contentW, $contentH, $marginRatio, $bg) {
  # Square canvas sized so the wordmark fills (1 - 2*marginRatio) of it,
  # leaving even, generous space on every side (no clipping under a
  # rounded-corner mask, no letters touching the edge).
  $side = [int]([Math]::Round(([Math]::Max($contentW, $contentH)) / (1 - 2 * $marginRatio)))
  $square = New-Object System.Drawing.Bitmap($side, $side)
  $g = [System.Drawing.Graphics]::FromImage($square)
  $g.Clear($bg)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $destX = [int](($side - $contentW) / 2)
  $destY = [int](($side - $contentH) / 2)
  $destRect = New-Object System.Drawing.Rectangle($destX, $destY, $contentW, $contentH)
  $srcRect = New-Object System.Drawing.Rectangle($left, $top, $contentW, $contentH)
  $g.DrawImage($bmp, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  return $square
}

function SaveResized($square, $size, $outPath) {
  $out = New-Object System.Drawing.Bitmap($size, $size)
  $g3 = [System.Drawing.Graphics]::FromImage($out)
  $g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g3.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g3.DrawImage($square, 0, 0, $size, $size)
  $g3.Dispose()
  $out.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose()
}

# Favicon: small canvas, modest margin (~12%) so the mark stays legible at 32px.
$faviconSquare = BuildIcon $bmp $left $top $contentW $contentH 0.12 $bg
SaveResized $faviconSquare 32 (Join-Path $root "images\favicon-32.png")
$faviconSquare.Dispose()

# Apple touch icon: bigger canvas, generous margin (~22%) so a rounded/
# masked corner on a home screen never touches a letter.
$touchSquare = BuildIcon $bmp $left $top $contentW $contentH 0.22 $bg
SaveResized $touchSquare 180 (Join-Path $root "images\apple-touch-icon.png")
$touchSquare.Dispose()

$bmp.Dispose()

Write-Output "done: content box left=$left top=$top w=$contentW h=$contentH"

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "images\logo-oras.png"
$bmp = New-Object System.Drawing.Bitmap($src)

# Auto-crop to the bounding box of non-near-white pixels, plus a small margin,
# so the tiny favicon shows the wordmark itself instead of mostly white padding.
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
function ColHasContent($bmp, $x, $h, $threshold) {
  for ($y = 0; $y -lt $h; $y++) {
    $p = $bmp.GetPixel($x, $y)
    if ($p.A -gt 10 -and ($p.R -lt $threshold -or $p.G -lt $threshold -or $p.B -lt $threshold)) { return $true }
  }
  return $false
}

$top = 0
while ($top -lt $h -and -not (RowHasContent $bmp $top $w $threshold)) { $top++ }
$bottom = $h - 1
while ($bottom -gt $top -and -not (RowHasContent $bmp $bottom $w $threshold)) { $bottom-- }
$left = 0
while ($left -lt $w -and -not (ColHasContent $bmp $left $h $threshold)) { $left++ }
$right = $w - 1
while ($right -gt $left -and -not (ColHasContent $bmp $right $h $threshold)) { $right-- }

# Only keep the wordmark line (top ~62% of the content box) so the tiny
# favicon renders the "ORAS" letters, not the illegible subtitle beneath.
$fullContentH = $bottom - $top + 1
$bottom = $top + [int]($fullContentH * 0.62)

$margin = 14
$cropX = [Math]::Max(0, $left - $margin)
$cropY = [Math]::Max(0, $top - $margin)
$cropW = [Math]::Min($w - $cropX, ($right - $left + 1) + $margin * 2)
$cropH = [Math]::Min($h - $cropY, ($bottom - $top + 1) + $margin * 2)

$cropped = New-Object System.Drawing.Bitmap($cropW, $cropH)
$g = [System.Drawing.Graphics]::FromImage($cropped)
$g.Clear([System.Drawing.Color]::White)
$g.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0, 0, $cropW, $cropH)), (New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)), [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()

# Pad to a square canvas (centered) so the icon isn't stretched.
$side = [Math]::Max($cropped.Width, $cropped.Height)
$square = New-Object System.Drawing.Bitmap($side, $side)
$g2 = [System.Drawing.Graphics]::FromImage($square)
$g2.Clear([System.Drawing.Color]::White)
$offX = [int](($side - $cropped.Width) / 2)
$offY = [int](($side - $cropped.Height) / 2)
$g2.DrawImage($cropped, $offX, $offY, $cropped.Width, $cropped.Height)
$g2.Dispose()

function SaveResized($square, $size, $outPath) {
  $out = New-Object System.Drawing.Bitmap($size, $size)
  $g3 = [System.Drawing.Graphics]::FromImage($out)
  $g3.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g3.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g3.Clear([System.Drawing.Color]::White)
  $g3.DrawImage($square, 0, 0, $size, $size)
  $g3.Dispose()
  $out.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose()
}

SaveResized $square 32 (Join-Path $root "images\favicon-32.png")
SaveResized $square 180 (Join-Path $root "images\apple-touch-icon.png")

$square.Dispose()
$cropped.Dispose()
$bmp.Dispose()

Write-Output "done: crop box x=$cropX y=$cropY w=$cropW h=$cropH, square side=$side"

# Publish helper: makes a SMALL copy of the site (optimized images) + zip.
# Originals are never touched. Pure-ASCII source.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root  = "C:\Users\asli-\Desktop\MUSTAFA\mustafacelik web"
$stage = Join-Path $env:TEMP "site-kucuk"
$zip   = "C:\Users\asli-\Desktop\mustafacelik-site-kucuk.zip"

if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
Copy-Item -LiteralPath $root -Destination $stage -Recurse
Remove-Item -LiteralPath (Join-Path $stage "tools") -Recurse -Force

$maxDim = 1400
$quality = 72
$renames = @{}

function Save-Jpeg([System.Drawing.Image]$img, [string]$path, [int]$q) {
  $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
  $par = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $par.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $q)
  $img.Save($path, $codec, $par)
  $par.Dispose()
}

function Shrink-In-Place([string]$path) {
  $bmp = [System.Drawing.Bitmap]::FromFile($path)
  try {
    $w = $bmp.Width
    $h = $bmp.Height
    $work = $bmp
    if ([math]::Max($w, $h) -gt $maxDim) {
      $r = $maxDim / [math]::Max($w, $h)
      $nw = [math]::Max(1, [int]($w * $r))
      $nh = [math]::Max(1, [int]($h * $r))
      $small = New-Object System.Drawing.Bitmap($nw, $nh)
      $g = [System.Drawing.Graphics]::FromImage($small)
      $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.DrawImage($bmp, 0, 0, $nw, $nh)
      $g.Dispose()
      $work = $small
    }
    $tmp = $path + ".tmp.jpg"
    Save-Jpeg $work $tmp $quality
    if ($work -ne $bmp) { $work.Dispose() }
  } finally {
    $bmp.Dispose()
  }
  Remove-Item -LiteralPath $path -Force
  Rename-Item -LiteralPath $tmp -NewName ([System.IO.Path]::GetFileName($path))
}

$files = Get-ChildItem -LiteralPath $stage -Recurse -File
foreach ($f in $files) {
  $ext = $f.Extension.ToLowerInvariant()
  $isImg = ($ext -eq ".jpg" -or $ext -eq ".jpeg" -or $ext -eq ".png")
  if (-not $isImg -and $f.Extension -eq "") {
    try {
      $probe = [System.Drawing.Bitmap]::FromFile($f.FullName)
      $probe.Dispose()
      $isImg = $true
    } catch { $isImg = $false }
  }
  if (-not $isImg) { continue }
  if ($f.Name -eq "imza.png") { continue }
  if ($ext -eq ".png" -and $f.Length -gt 300KB) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $newName = $stem + ".jpg"
    Shrink-In-Place $f.FullName
    Rename-Item -LiteralPath $f.FullName -NewName $newName
    $renames[$f.Name] = $newName
  } else {
    Shrink-In-Place $f.FullName
  }
}

# extensionless image -> add .jpg so hosts serve correct mime
foreach ($f in (Get-ChildItem -LiteralPath $stage -Recurse -File)) {
  if ($f.Extension -eq "" -and -not ($f.Name -like "*.txt") -and -not ($f.Name -like "*.html") -and -not ($f.Name -like "*.css") -and -not ($f.Name -like "*.js") -and -not ($f.Name -like "*.bat") -and -not ($f.Name -like "*.ps1")) {
    try {
      $probe = [System.Drawing.Bitmap]::FromFile($f.FullName)
      $probe.Dispose()
      $newName = $f.Name + ".jpg"
      Rename-Item -LiteralPath $f.FullName -NewName $newName
      $renames[$f.Name] = $newName
    } catch { }
  }
}

# fix html references for renamed files
if ($renames.Count -gt 0) {
  $htmls = Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object { $_.Extension -eq ".html" }
  foreach ($h in $htmls) {
    $t = Get-Content -LiteralPath $h.FullName -Raw -Encoding UTF8
    $changed = $false
    foreach ($k in $renames.Keys) {
      $old = [System.Uri]::EscapeDataString($k)
      $new = [System.Uri]::EscapeDataString($renames[$k])
      if ($t.Contains($old)) {
        $t = $t.Replace($old, $new)
        $changed = $true
      }
    }
    if ($changed) {
      [System.IO.File]::WriteAllText($h.FullName, $t, (New-Object System.Text.UTF8Encoding($true)))
    }
  }
}

if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip
$zi = Get-Item -LiteralPath $zip
Write-Output ("ZIP MB: " + [math]::Round($zi.Length / 1MB, 1))
Write-Output ("renamed images: " + $renames.Count)
foreach ($k in $renames.Keys) { Write-Output ("renamed: " + $k + " -> " + $renames[$k]) }

# Blog generator: builds blog.html (listing) + blog/<slug>.html (detail)
# Source of truth: bloglar/*.txt (title = file name, body = content)
# Cover: same-stem image discovered by enumeration (jpg/jpeg/png any case, or extensionless image)
# Markers: **kapak** -> cover figure (marker removed); **<stem>** -> same-stem image figure
# NOTE: this script is intentionally pure-ASCII; all Turkish copy lives in tools/blog-tpl/*.html
$ErrorActionPreference = "Stop"

$root    = "C:\Users\asli-\Desktop\MUSTAFA\mustafacelik web"
$blogDir = Join-Path $root "bloglar"
$tplDir  = Join-Path $root "tools\blog-tpl"
$outDir  = Join-Path $root "blog"

function Read-Utf8([string]$p) {
  return Get-Content -LiteralPath $p -Raw -Encoding UTF8
}

function Write-Utf8Bom([string]$p, [string]$s) {
  $enc = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($p, $s, $enc)
}

function Get-Slug([string]$name) {
  $s = $name.ToLowerInvariant()
  $keys = @(0x131, 0x130, 0x15F, 0x15E, 0x11F, 0x11E, 0xFC, 0xDC, 0xF6, 0xD6, 0xE7, 0xC7)
  $vals = @("i", "i", "s", "s", "g", "g", "u", "u", "o", "o", "c", "c")
  for ($i = 0; $i -lt $keys.Count; $i++) {
    $s = $s.Replace([string][char]$keys[$i], $vals[$i])
  }
  $s = [regex]::Replace($s, "[^a-z0-9]+", "-")
  return $s.Trim("-")
}

function Esc([string]$s) {
  return [System.Net.WebUtility]::HtmlEncode($s)
}

function UrlFile([string]$name) {
  return [System.Uri]::EscapeDataString($name)
}

$allFiles = Get-ChildItem -LiteralPath $blogDir -File
$txtFiles  = @($allFiles | Where-Object { $_.Extension -eq ".txt" } | Sort-Object Name)
$otherFiles = @($allFiles | Where-Object { $_.Extension -ne ".txt" })

function Find-Image([string]$stem) {
  foreach ($f in $otherFiles) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    if ($base -eq $stem) {
      if ($f.Extension -ne "") { return $f.Name }
      $fs = [System.IO.File]::OpenRead($f.FullName)
      $buf = New-Object byte[] 2
      [void]$fs.Read($buf, 0, 2)
      $fs.Close()
      if (($buf[0] -eq 0xFF -and $buf[1] -eq 0xD8) -or ($buf[0] -eq 0x89 -and $buf[1] -eq 0x50)) {
        return $f.Name
      }
    }
  }
  return $null
}

function Convert-Block([string]$block, [string]$coverFile, [string]$title, [string]$imgRel, [bool]$isFirst, [ref]$figCount) {
  $t = $block.Trim()
  if ($t -match '^\*\*(.+?)\*{1,2}$') {
    $inner = $Matches[1].Trim()
    if ($inner.Contains([char]10) -or $inner.Contains([char]13)) {
      return "<p>" + (Esc $t) + "</p>"
    }
    if ($inner -eq "kapak") {
      if ($coverFile -ne $null -and $coverFile -ne "") {
        $figCount.Value++
        return "<figure class=""post-figure""><img src=""" + $imgRel + (UrlFile $coverFile) + """ alt=""" + (Esc $title) + """ loading=""lazy"" /></figure>"
      }
      return ""
    }
    $img = Find-Image $inner
    if ($img -ne $null -and $img -ne "") {
      $figCount.Value++
      return "<figure class=""post-figure""><img src=""" + $imgRel + (UrlFile $img) + """ alt=""" + (Esc $inner) + """ loading=""lazy"" /><figcaption>" + (Esc $inner) + "</figcaption></figure>"
    }
    return "<h3>" + (Esc $inner) + "</h3>"
  }
  $single = -not ($t.Contains([char]10))
  if ($single -and $t.Length -lt 160 -and $t -match '^\d+\.\s') {
    return "<h3>" + (Esc $t) + "</h3>"
  }
  if ($single -and $t.Length -lt 160 -and $t.StartsWith("Sonu")) {
    return "<h3>" + (Esc $t) + "</h3>"
  }
  $joined = [regex]::Replace($t, "\s+", " ").Trim()
  if ($isFirst) {
    return "<p class=""lede"">" + (Esc $joined) + "</p>"
  }
  return "<p>" + (Esc $joined) + "</p>"
}

# ---- collect posts ----
$posts = @()
$usedSlugs = @{}
foreach ($f in $txtFiles) {
  $title = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
  $slug = Get-Slug $title
  if ($slug -eq "") { $slug = "yazi" }
  $n = 2
  while ($usedSlugs.ContainsKey($slug)) {
    $slug = (Get-Slug $title) + "-" + $n
    $n++
  }
  $usedSlugs[$slug] = $true
  $cover = Find-Image $title
  $raw = Read-Utf8 $f.FullName
  $posts += [pscustomobject]@{ Title = $title; Slug = $slug; Cover = $cover; Raw = $raw; Txt = $f.Name }
}

if ($posts.Count -eq 0) { throw "no txt files found" }

# ---- templates ----
$head = Read-Utf8 (Join-Path $tplDir "_head.html")
$foot = Read-Utf8 (Join-Path $tplDir "_foot.html")
$listingTpl = Read-Utf8 (Join-Path $tplDir "_listing.html")
$cardTpl = Read-Utf8 (Join-Path $tplDir "_card.html")
$detailTpl = Read-Utf8 (Join-Path $tplDir "_detail.html")

if (-not (Test-Path -LiteralPath $outDir)) {
  [void](New-Item -ItemType Directory -Force -Path $outDir)
}

# ---- detail pages ----
for ($i = 0; $i -lt $posts.Count; $i++) {
  $p = $posts[$i]
  $blocks = [regex]::Split($p.Raw, "`r?`n[ \t]*`r?`n")
  $html = @()
  $firstDone = $false
  $figs = 0
  $textForStats = @()
  foreach ($b in $blocks) {
    $t = "$b".Trim()
    if ($t -eq "") { continue }
    $isMarker = $t -match '^\*\*(.+?)\*{1,2}$'
    if (-not $isMarker) {
      $textForStats += [regex]::Replace($t, "\s+", " ").Trim()
    }
    $frag = Convert-Block $t $p.Cover $p.Title "../bloglar/" (-not $firstDone -and -not $isMarker) ([ref]$figs)
    if (-not $isMarker) { $firstDone = $true }
    if ($frag -ne "") { $html += $frag }
  }
  $allText = ($textForStats -join " ")
  $words = @($allText -split "\s+" | Where-Object { $_ -ne "" }).Count
  $mins = [math]::Max(1, [math]::Round($words / 200))

  $prevNext = @()
  if ($i -gt 0) {
    $q = $posts[$i - 1]
    $prevNext += "<a class=""btn btn-ghost"" href=""" + $q.Slug + ".html"">&larr; " + (Esc $q.Title) + "</a>"
  }
  if ($i -lt ($posts.Count - 1)) {
    $q = $posts[$i + 1]
    $prevNext += "<a class=""btn btn-ghost"" href=""" + $q.Slug + ".html"">" + (Esc $q.Title) + " &rarr;</a>"
  }

  $excerpt = $allText
  if ($excerpt.Length -gt 170) {
    $cut = $excerpt.Substring(0, 170)
    $sp = $cut.LastIndexOf(" ")
    if ($sp -gt 90) { $cut = $cut.Substring(0, $sp) }
    $excerpt = $cut + "..."
  }

  $body = $detailTpl.Replace("[[TITLE]]", (Esc $p.Title))
  $body = $body.Replace("[[READTIME]]", "$mins")
  $body = $body.Replace("[[BODYHTML]]", ($html -join "`n"))
  $body = $body.Replace("[[PREVNEXT]]", ($prevNext -join "`n          "))
  $body = $body.Replace("[[ROOT]]", "../")

  $page = $head.Replace("[[TITLE]]", (Esc $p.Title))
  $page = $page.Replace("[[DESC]]", (Esc $excerpt))
  $page = $page.Replace("[[ROOT]]", "../")
  $page += $body
  $page += $foot.Replace("[[ROOT]]", "../")

  Write-Utf8Bom (Join-Path $outDir ($p.Slug + ".html")) $page
  $p | Add-Member -NotePropertyName Excerpt -NotePropertyValue $excerpt -Force
  $p | Add-Member -NotePropertyName Mins -NotePropertyValue $mins -Force
  $p | Add-Member -NotePropertyName Figs -NotePropertyValue $figs -Force
}

# ---- listing page ----
$cards = @()
foreach ($p in $posts) {
  if ($p.Cover -ne $null -and $p.Cover -ne "") {
    $img = "bloglar/" + (UrlFile $p.Cover)
  } else {
    $img = ""
  }
  $c = $cardTpl.Replace("[[URL]]", ("blog/" + $p.Slug + ".html"))
  $c = $c.Replace("[[IMG]]", $img)
  $c = $c.Replace("[[TITLE]]", (Esc $p.Title))
  $c = $c.Replace("[[EXCERPT]]", (Esc $p.Excerpt))
  $c = $c.Replace("[[READTIME]]", "$($p.Mins)")
  $cards += $c
}
$listingBody = $listingTpl.Replace("[[CARDS]]", ($cards -join "`n"))
$listingBody = $listingBody.Replace("[[COUNT]]", "$($posts.Count)")

$listing = $head.Replace("[[TITLE]]", "Blog")
$C = [string][char]0xC7
$I = [string][char]0x131
$U = [string][char]0xFC
$listingDesc = "Mustafa " + $C + "elik Real Estate blog yaz" + $I + "lar" + $I + ": ticari, l" + $U + "ks konut, arsa ve global pazar analizleri."
$listing = $listing.Replace("[[DESC]]", (Esc $listingDesc))
$listing = $listing.Replace("[[ROOT]]", "")
$listing += $listingBody
$listing += $foot.Replace("[[ROOT]]", "")

Write-Utf8Bom (Join-Path $root "blog.html") $listing

# ---- report ----
Write-Output ("posts: " + $posts.Count)
foreach ($p in $posts) {
  $hasCover = "NO-COVER"
  if ($p.Cover -ne $null -and $p.Cover -ne "") { $hasCover = "cover-ok" }
  Write-Output ($p.Slug + " | figs=" + $p.Figs + " | " + $hasCover + " | " + $p.Title)
}

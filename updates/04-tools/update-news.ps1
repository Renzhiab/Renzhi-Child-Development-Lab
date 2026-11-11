$ErrorActionPreference = 'Stop'

$siteDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$draftDir = Join-Path $siteDir 'updates\01-drafts'
$outputPath = Join-Path $siteDir 'updates\03-data\news-data.js'

if (-not (Test-Path -LiteralPath $draftDir -PathType Container)) {
    throw "未找到动态稿件文件夹：$draftDir"
}

$draftFiles = Get-ChildItem -LiteralPath $draftDir -Filter '*.md' -File |
    Where-Object {
        $_.Name -notmatch '^_' -and
        $_.BaseName -notin @('动态字段与排版说明', 'README')
    } |
    Sort-Object Name

$news = @()
$allowedCategories = @('通知公告', '学术动态', '生活动态')

foreach ($file in $draftFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    $match = [regex]::Match($text, '(?s)^---\s*\r?\n(.*?)\r?\n---\s*\r?\n?(.*)$')
    if (-not $match.Success) {
        throw "稿件格式错误：$($file.Name)。文件开头和字段区之后都必须有 ---。"
    }

    $fields = @{}
    foreach ($line in ($match.Groups[1].Value -split '\r?\n')) {
        $fieldMatch = [regex]::Match($line, '^([A-Za-z][A-Za-z0-9]*):\s*(.*)$')
        if ($fieldMatch.Success) {
            $fields[$fieldMatch.Groups[1].Value] = $fieldMatch.Groups[2].Value.Trim()
        }
    }

    $dateText = [string]$fields['date']
    $dateMatch = [regex]::Match($dateText, '^(\d{4})[.\-/](\d{2})[.\-/](\d{2})$')
    if (-not $dateMatch.Success) {
        throw "日期格式错误：$($file.Name)。请使用 YYYY.MM.DD，例如 2026.11.12。"
    }
    $normalizedDate = "$($dateMatch.Groups[1].Value).$($dateMatch.Groups[2].Value).$($dateMatch.Groups[3].Value)"

    $category = [string]$fields['category']
    if ($category -notin $allowedCategories) {
        throw "分类错误：$($file.Name)。category 只能填写：$($allowedCategories -join '、')。"
    }
    $title = [string]$fields['title']
    if ([string]::IsNullOrWhiteSpace($title)) {
        throw "缺少标题：$($file.Name)。请填写 title。"
    }

    $image = [string]$fields['image']
    if ([string]::IsNullOrWhiteSpace($image)) {
        $image = 'website-assets/01-brand/logo.png'
    }
    if ($image -notmatch '^(https?:)?//' -and -not (Test-Path -LiteralPath (Join-Path $siteDir $image))) {
        throw "图片不存在：$($file.Name) 中的 image 为 $image。"
    }

    $body = $match.Groups[2].Value.Trim()
    $contentZh = $body
    $contentEn = ''
    $englishMarker = '<!-- English -->'
    if ($body.Contains($englishMarker)) {
        $parts = $body -split [regex]::Escape($englishMarker), 2
        $contentZh = $parts[0].Trim()
        $contentEn = $parts[1].Trim()
    }
    if ([string]::IsNullOrWhiteSpace($contentZh)) {
        $contentZh = [string]$fields['summary']
    }
    $order = 0
    if (-not [int]::TryParse([string]$fields['order'], [ref]$order)) {
        $order = 0
    }

    $news += [ordered]@{
        date = $normalizedDate
        cat = $category
        tag = [string]$fields['tag']
        icon = if ([string]::IsNullOrWhiteSpace([string]$fields['icon'])) { '📰' } else { [string]$fields['icon'] }
        img = $image
        link = [string]$fields['link']
        order = $order
        title = $title
        titleEn = [string]$fields['titleEn']
        content = $contentZh
        contentEn = $contentEn
    }
}

$news = @($news | Sort-Object @{ Expression = { [datetime]::ParseExact($_.date, 'yyyy.MM.dd', $null) }; Descending = $true }, @{ Expression = { [int]$_.order }; Descending = $true }, @{ Expression = { $_.title } })
$jsonItems = @($news | ForEach-Object { $_ | ConvertTo-Json -Depth 6 -Compress })
$json = '[' + ($jsonItems -join ',') + ']'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outputPath, "window.LAB_NEWS = $json;`r`n", $utf8NoBom)
Write-Host "已更新 $($news.Count) 条动态：$outputPath" -ForegroundColor Green

$ErrorActionPreference = "Stop"

$chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chrome)) {
    throw "Chrome executable not found at $chrome"
}

Add-Type -AssemblyName System.Drawing

$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $baseDir "out"
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$targets = @(
    @{ Html = "thumbnail.html"; Out = "kmong-pro-thumbnail-652x488.png"; W = 652; H = 488; Scale = 1; Trim = $false },
    @{ Html = "thumbnail.html"; Out = "kmong-pro-thumbnail-1304x976.png"; W = 652; H = 488; Scale = 2; Trim = $false },
    @{ Html = "detail-01-hook.html"; Out = "kmong-pro-detail-01-hook.png"; W = 860; H = 1800; Scale = 1; Trim = $true },
    @{ Html = "detail-02-comparison.html"; Out = "kmong-pro-detail-02-comparison.png"; W = 860; H = 1800; Scale = 1; Trim = $true },
    @{ Html = "detail-03-showcase.html"; Out = "kmong-pro-detail-03-showcase.png"; W = 860; H = 1800; Scale = 1; Trim = $true },
    @{ Html = "detail-04-admin-trust.html"; Out = "kmong-pro-detail-04-admin-trust.png"; W = 860; H = 1800; Scale = 1; Trim = $true },
    @{ Html = "detail-05-pricing.html"; Out = "kmong-pro-detail-05-pricing.png"; W = 860; H = 1800; Scale = 1; Trim = $true },
    @{ Html = "detail-06-process-faq.html"; Out = "kmong-pro-detail-06-process-faq.png"; W = 860; H = 1800; Scale = 1; Trim = $true }
)

function Trim-BottomWhitespace([string]$pngPath, [int]$bottomPad = 40) {
    $bmp = [System.Drawing.Bitmap]::FromFile($pngPath)
    $w = $bmp.Width
    $h = $bmp.Height
    $lastContentY = $h - 1

    for ($y = $h - 1; $y -ge 0; $y--) {
        $foundContent = $false
        for ($x = 0; $x -lt $w; $x += 4) {
            $p = $bmp.GetPixel($x, $y)
            # Detect non-white and non-slate-bg (#f8fafc) content pixels
            if ($p.R -lt 245 -or $p.G -lt 246 -or $p.B -lt 248) {
                $foundContent = $true
                break
            }
        }
        if ($foundContent) {
            $lastContentY = $y
            break
        }
    }

    $newH = [Math]::Min($h, $lastContentY + 1 + $bottomPad)
    if ($newH -lt $h -and $newH -gt 200) {
        $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $newH)
        $cropped = $bmp.Clone($rect, $bmp.PixelFormat)
        $bmp.Dispose()
        $cropped.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $cropped.Dispose()
    } else {
        $bmp.Dispose()
    }
}

foreach ($t in $targets) {
    $htmlPath = Join-Path $baseDir $t.Html
    if (-not (Test-Path $htmlPath)) {
        throw "Missing HTML file: $htmlPath"
    }
    $outPath = Join-Path $outDir $t.Out
    $fileUri = ([System.Uri]$htmlPath).AbsoluteUri

    $args = @(
        "--headless=new",
        "--disable-gpu",
        "--hide-scrollbars",
        "--allow-file-access-from-files",
        "--virtual-time-budget=4000",
        "--window-size=$($t.W),$($t.H)",
        "--force-device-scale-factor=$($t.Scale)",
        "--screenshot=$outPath",
        $fileUri
    )

    $proc = Start-Process -FilePath $chrome -ArgumentList $args -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0 -or -not (Test-Path $outPath)) {
        throw "Failed to render $($t.Out) (ExitCode=$($proc.ExitCode))"
    }

    if ($t.Trim) {
        Trim-BottomWhitespace -pngPath $outPath -bottomPad 44
    }
}

Write-Host "=== Rendered Pro-Services PNG Dimensions ==="
foreach ($t in $targets) {
    $outPath = Join-Path $outDir $t.Out
    $img = [System.Drawing.Image]::FromFile($outPath)
    $w = $img.Width
    $h = $img.Height
    $img.Dispose()
    $sizeKb = [math]::Round((Get-Item $outPath).Length / 1KB, 1)
    Write-Host ("{0,-38} {1}x{2} px  ({3} KB)" -f $t.Out, $w, $h, $sizeKb)
}

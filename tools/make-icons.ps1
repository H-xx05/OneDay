# 由 tools/logo-source.png 生成全部应用图标(Windows PowerShell,运行一次即可)
# 会自动定位 logo 中的黑色圆形主体,四种变体:
#   icon-192/512.png          透明底圆形裁切(Android "any" + 网站图标)
#   icon-maskable-512.png     纸色方底 + 居中 logo(Android 自适应图标,内容留在安全区)
#   apple-touch-icon.png      纸色方底 + 居中 logo(iOS 添加到主屏幕)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$srcPath = Join-Path $PSScriptRoot 'logo-source.png'
$src = New-Object System.Drawing.Bitmap($srcPath)

# --- 扫描深色像素得到 logo 圆形主体的边界(隔一个像素取一次,加速) ---
$rect = New-Object System.Drawing.Rectangle(0, 0, $src.Width, $src.Height)
$bd = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bytes = New-Object byte[] ($bd.Stride * $src.Height)
[System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $bytes.Length)
$src.UnlockBits($bd)

$minX = $src.Width; $minY = $src.Height; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $src.Height; $y += 2) {
    $row = $y * $bd.Stride
    for ($x = 0; $x -lt $src.Width; $x += 2) {
        $i = $row + $x * 4
        if ($bytes[$i + 3] -gt 10 -and $bytes[$i + 2] -lt 128) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}
if ($maxX -lt 0) { throw '未在 logo 中找到深色圆形主体' }
$srcRect = New-Object System.Drawing.Rectangle($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
Write-Host ("logo 主体区域: {0},{1} {2}x{3}" -f $minX, $minY, $srcRect.Width, $srcRect.Height)

$paper = [System.Drawing.Color]::FromArgb(255, 0xFA, 0xF5, 0xEC)   # 与应用纸色一致

function New-Graphics([System.Drawing.Bitmap]$bmp) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    return $g
}

function Make-Round([int]$size, [string]$path) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = New-Graphics $bmp
    $clip = New-Object System.Drawing.Drawing2D.GraphicsPath
    $clip.AddEllipse(0, 0, $size, $size)
    $g.SetClip($clip)
    $dst = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $g.DrawImage($src, $dst, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "saved $path"
}

function Make-OnPaper([int]$size, [string]$path, [single]$logoRatio) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = New-Graphics $bmp
    $g.Clear($paper)
    $d = [int]($size * $logoRatio)
    $off = [int](($size - $d) / 2)
    $clip = New-Object System.Drawing.Drawing2D.GraphicsPath
    $clip.AddEllipse($off, $off, $d, $d)          # 源图白底无透明,按圆形裁掉
    $g.SetClip($clip)
    $dst = New-Object System.Drawing.Rectangle($off, $off, $d, $d)
    $g.DrawImage($src, $dst, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "saved $path"
}

Make-Round 512 "$PSScriptRoot\..\icon-512.png"
Make-Round 192 "$PSScriptRoot\..\icon-192.png"
Make-OnPaper 512 "$PSScriptRoot\..\icon-maskable-512.png" 0.74
Make-OnPaper 180 "$PSScriptRoot\..\apple-touch-icon.png" 0.80
$src.Dispose()

[CmdletBinding()]
param (
    [string]$Text = "DS",
    [string]$Top = "#CF7040",
    [string]$Bottom = "#B95E30",
    [string]$TextColor = "#FFFFFF",
    [int]$Size = 256,
    [string]$Out = "terminal-icon.png"
)

# Generates the Windows Terminal profile icon shipped in this folder, and the
# icon of any other project that wants one: the script has no dependency on
# this repository, so copying this single file is enough to reuse it.
#
#   .\make-icon.ps1                                  # regenerate in place
#   .\make-icon.ps1 -Text ML -Top "#3B82F6"          # another monogram, blue
#
# The monogram width, the corner radius and the gradient direction are fixed on
# purpose: they were chosen by eye for legibility at tab size (~16 px), where a
# gradient reads as a flat colour and any fine detail disappears.
#
# Two GDI+ details worth keeping if this is ever rewritten:
#   - FillMode.Winding. Glyph outlines overlap, and the default (Alternate)
#     treats an overlap as a hole: the D's stem gets a hairline vertical seam.
#   - centring on the glyph INK bounds, not the font em box. The em box keeps
#     room for descenders this monogram does not have, so the text sits high.

Add-Type -AssemblyName System.Drawing

$family = $null
foreach ($name in @("Cascadia Mono", "Cascadia Code", "Consolas", "Segoe UI")) {
    try { $family = New-Object System.Drawing.FontFamily($name); break } catch { }
}
if (-not $family) { throw "No usable font family found on this machine." }

# A glyph outline path, sized in pixels
function Get-Monogram([single]$PixelSize) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.FillMode = [System.Drawing.Drawing2D.FillMode]::Winding
    $path.AddString($Text, $family, [int][System.Drawing.FontStyle]::Bold, $PixelSize,
                     (New-Object System.Drawing.PointF(0, 0)),
                     [System.Drawing.StringFormat]::GenericTypographic)
    return $path
}

function ConvertTo-Color([string]$Html) {
    return [System.Drawing.ColorTranslator]::FromHtml($Html)
}

$bitmap = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$canvas = [System.Drawing.Graphics]::FromImage($bitmap)
$canvas.SmoothingMode = 'AntiAlias'
$canvas.Clear([System.Drawing.Color]::Transparent)

# Rounded to a whole pixel: a fractional margin puts the tile edge mid-pixel,
# which softens it - and it keeps this script byte-identical to the icon
# already committed, so the file in this folder provably comes from here.
$margin = [single][Math]::Round($Size * 0.023)
$rect = New-Object System.Drawing.RectangleF($margin, $margin,
            [single]($Size - 2 * $margin), [single]($Size - 2 * $margin))

# Rounded square: radius is 22% of the side
$radius = [single]($rect.Width * 0.22)
$diameter = [single]($radius * 2)
$tile = New-Object System.Drawing.Drawing2D.GraphicsPath
$tile.AddArc($rect.X, $rect.Y, $diameter, $diameter, [single]180, [single]90)
$tile.AddArc(($rect.Right - $diameter), $rect.Y, $diameter, $diameter, [single]270, [single]90)
$tile.AddArc(($rect.Right - $diameter), ($rect.Bottom - $diameter), $diameter, $diameter, [single]0, [single]90)
$tile.AddArc($rect.X, ($rect.Bottom - $diameter), $diameter, $diameter, [single]90, [single]90)
$tile.CloseFigure()

$gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect, (ConvertTo-Color $Top), (ConvertTo-Color $Bottom), 90)
$canvas.FillPath($gradient, $tile)

# Size the monogram from a reference render, then fit it to whichever side runs
# out first: that keeps a one-letter mark from overflowing the tile vertically.
$probe = Get-Monogram 100
$probeBounds = $probe.GetBounds()
$probe.Dispose()
$scale = [Math]::Min(($rect.Width * 0.74) / $probeBounds.Width,
                     ($rect.Height * 0.74) / $probeBounds.Height)

$monogram = Get-Monogram ([single](100 * $scale))
$bounds = $monogram.GetBounds()
$shift = New-Object System.Drawing.Drawing2D.Matrix
$shift.Translate([single]($rect.X + ($rect.Width - $bounds.Width) / 2 - $bounds.X),
                 [single]($rect.Y + ($rect.Height - $bounds.Height) / 2 - $bounds.Y))
$monogram.Transform($shift)
$canvas.FillPath((New-Object System.Drawing.SolidBrush((ConvertTo-Color $TextColor))), $monogram)

$target = [System.IO.Path]::GetFullPath($Out)
$bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
$canvas.Dispose()
$bitmap.Dispose()

Write-Host ("Wrote {0}" -f $target)
Write-Host ("  {0}x{0} px, monogram '{1}', {2} -> {3}" -f $Size, $Text, $Top, $Bottom)

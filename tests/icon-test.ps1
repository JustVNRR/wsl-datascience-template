# Draws icons the way the build draws them, and reads back what was drawn.
#
# Two things are checked, and the second one is why every drawing here is a
# PowerShell process of its own:
#   - the letters: what a name turns into (wagon -> WA, my-project -> MP), and
#     that a piece opening on a digit is not a word (Ubuntu-22.04 -> UB),
#   - the colours: a name always draws the same file. A hash seeded per process
#     would answer the same twice INSIDE one process and differently in the
#     next - the icon would change colour at every build - so the two drawings
#     below are made by two processes, and their bytes are compared.
#
# It needs no instance, no console and no Docker.
#
# Usage:  powershell -NoProfile -File tests\icon-test.ps1

$ErrorActionPreference = "Stop"

$IconScript = Join-Path $PSScriptRoot "..\assets\make-icon.ps1"
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("icon-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Tmp -Force | Out-Null

$Failures = 0
function Check {
    param([string]$Name, $Got, $Expected)
    if ("$Got" -eq "$Expected") {
        Write-Output "OK   $Name"
    } else {
        Write-Output "FAIL $Name : expected '$Expected', got '$Got'"
        $script:Failures++
    }
}

# One drawing, in a process of its own. Returns what it printed, or $null when
# it failed: a drawing that cannot be made must say so, not write an empty file.
# (Write-Host for the same reason - Write-Output would travel back with the
# return value, which is how a captured result swallows what it captured.)
function Invoke-Icon {
    param([string[]]$Arguments)

    # The child's error output is read, not thrown: what a drawing that failed
    # has to give us is its message and its exit code. Left at "Stop", the
    # redirection below turns one line of stderr into a terminating error here,
    # which would end the suite instead of failing one check.
    $Preference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Lines = & powershell -NoProfile -File $IconScript @Arguments 2>&1
        $Code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $Preference
    }

    if ($Code -ne 0) {
        # Its first line only: the rest of a PowerShell error block is the same
        # sentence again, in the language of whoever's Windows answers.
        Write-Host ("      (the drawing failed: " + @($Lines)[0] + ")")
        return $null
    }
    return $Lines
}

# What the script said it drew: its line reads "monogram 'WA', #CF7040 -> ..."
function Get-DrawnLetters {
    param([string[]]$Arguments)

    $Lines = Invoke-Icon $Arguments
    $Line = @($Lines | Where-Object { "$_" -match "monogram '" })[0]
    if ($Line -match "monogram '([^']*)'") { return $Matches[1] }
    return "<nothing drawn>"
}

$Letters = @(
    @{ Name = "wagon";        Expect = "WA" },
    @{ Name = "distro";       Expect = "DI" },
    @{ Name = "ml";           Expect = "ML" },
    @{ Name = "my-project";   Expect = "MP" },
    @{ Name = "new_distro2";  Expect = "ND" },
    @{ Name = "Ubuntu-22.04"; Expect = "UB" },
    @{ Name = "2fast";        Expect = "2F" },
    @{ Name = "x";            Expect = "X" }
)

foreach ($Case in $Letters) {
    $Out = Join-Path $Tmp ("letters-" + $Case.Name + ".png")
    $Got = Get-DrawnLetters @("-Name", $Case.Name, "-Out", $Out)
    Check ("letters of '" + $Case.Name + "'") $Got $Case.Expect
}

# The colours: one name, two processes, the same file.
$First = Join-Path $Tmp "same-name-1.png"
$Second = Join-Path $Tmp "same-name-2.png"
$null = Invoke-Icon @("-Name", "wagon", "-Out", $First, "-Quiet")
$null = Invoke-Icon @("-Name", "wagon", "-Out", $Second, "-Quiet")
Check "the same name draws the same file, in two processes" `
    (Get-FileHash $First).Hash (Get-FileHash $Second).Hash

# And the colours come from the name, not from the letters: the same monogram
# typed by hand - same letters as 'wagon' - is drawn on the table's first row.
$ByHand = Join-Path $Tmp "by-hand.png"
$null = Invoke-Icon @("-Text", "WA", "-Out", $ByHand, "-Quiet")
Check "the same letters, another name, another colour" `
    ((Get-FileHash $First).Hash -ne (Get-FileHash $ByHand).Hash) $true

Check "a monogram given by hand is drawn as asked" `
    (Get-DrawnLetters @("-Text", "ML", "-Out", (Join-Path $Tmp "by-hand-ml.png"))) "ML"

# Nothing to draw is refused, and leaves no file behind.
$Nothing = Join-Path $Tmp "nothing.png"
Check "neither -Name nor -Text: refused" ($null -eq (Invoke-Icon @("-Out", $Nothing))) $true
Check "and no file was written" (Test-Path $Nothing) $false

# What comes out is a picture: the PNG signature, and bytes behind it.
$Bytes = [System.IO.File]::ReadAllBytes($First)
Check "the icon is a PNG" (($Bytes[0..7] | ForEach-Object { $_.ToString("X2") }) -join "") "89504E470D0A1A0A"
Check "and it has pixels in it" ($Bytes.Length -gt 1000) $true

Remove-Item -Recurse -Force $Tmp

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures

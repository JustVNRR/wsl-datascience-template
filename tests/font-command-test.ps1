# Drives `font` - the command behind `.\wsl.ps1 theme` - the way a script would:
# the numbered prompt, answers on standard input, no console anywhere.
#
# The instance it works on exists for the length of the test: a registry key of
# its own, a folder carrying the marker, and the WSL fragment Windows Terminal
# reads a profile from, so that the font has a profile to be applied to. All
# three are taken back out at the end, whatever happens.
#
# What is checked is what the command is for: the list it draws is the fonts a
# terminal can use - monospaced, and without the symbol fonts Windows ships -
# the font in use is marked, and picking one writes it into the profile this
# repository owns and into the instance's own file. The list is read from a first
# run that cancels, so the number to give on the second one is a number that was
# really there.
#
# It needs no instance, no console and no Docker Desktop.
#
# Usage:  powershell -NoProfile -File tests\font-command-test.ps1

$ErrorActionPreference = "Stop"

# For Get-Distros and the marker test: the list the command itself builds.
. (Join-Path $PSScriptRoot "..\scripts\instance.ps1")

$FontScript = Join-Path $PSScriptRoot "..\scripts\font.ps1"
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("font-command-test-" + [Guid]::NewGuid().ToString("N"))
$FakeName = "font-command-test"
$FakeFolder = Join-Path $Tmp "instance"
$Recipe = Join-Path $FakeFolder "instance.json"
$Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e5f}"

# The profile Windows Terminal knows an instance by: a fragment WSL writes, and
# the one thing this repository layers its own fragment over.
$WslFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\Microsoft.WSL\{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e6f}.json"
$OurFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-datascience-template\$FakeName.json"
$OurFragmentExisted = Test-Path $OurFragment

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

function Invoke-Font {
    param([string[]]$Answers)

    $Preference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Lines = $Answers | & powershell -NoProfile -File $FontScript 2>&1
    } finally {
        $ErrorActionPreference = $Preference
    }
    return $Lines
}

# The rows of the numbered list, as the command drew them: the font names, in
# order. The first column of each row is its number.
#
# Read from the title of the font menu down: the instance list the command asks
# about first is drawn the same way - number, name, more - and its rows are not
# fonts. (They were counted as fonts once, and the number given to the second run
# then pointed at something else.)
function Get-ListedFonts {
    param([object[]]$Lines)

    $Rows = @()
    $Inside = $false
    foreach ($Line in $Lines) {
        if ("$Line" -like "Font of '*'") { $Inside = $true; continue }
        if (-not $Inside) { continue }
        if ("$Line" -match '^\s*(\d+)\.\s+(\S.*?)\s*$') {
            if ($Matches[1] -eq "0") { return $Rows }
            $Rows += ($Matches[2] -replace '\s{2,}.*$', '')
        }
    }
    return $Rows
}

New-Item -ItemType Directory -Path $FakeFolder -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $FakeFolder ".wsl-datascience-template") -Force | Out-Null

try {
    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path $Key -Force | Out-Null
    Set-ItemProperty -Path $Key -Name DistributionName -Value $FakeName
    Set-ItemProperty -Path $Key -Name BasePath -Value $FakeFolder

    New-Item -ItemType Directory -Path (Split-Path -Parent $WslFragment) -Force | Out-Null
    Set-Content -Path $WslFragment -Encoding Utf8 -Value @"
{
    "profiles": [
        {
            "name": "$FakeName",
            "guid": "{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e6f}"
        }
    ]
}
"@

    $All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.BasePath } | Sort-Object Name)
    $Pick = [array]::IndexOf(@($All.Name), $FakeName) + 1
    Check "the test's instance is in the list" ($Pick -ge 1) $true

    # 1. The list, read off a run that cancels: nothing is applied, and what it
    # drew is what the second run will be asked for
    $Out = Invoke-Font @("$Pick", "0")
    $Fonts = @(Get-ListedFonts $Out)
    Check "the fonts are listed" ($Fonts.Count -ge 5) $true
    Check "a font this machine is sure to have is in it" ($Fonts -contains "Consolas") $true
    Check "and the symbol fonts are not" (@($Fonts | Where-Object { $_ -like "Wingdings*" }).Count) 0
    Check "the one in use is marked" (@($Out | Where-Object { "$_" -like "*(current)*" }).Count -gt 0) $true
    Check "cancelling applied nothing" (Test-Path $OurFragment) $OurFragmentExisted

    # 2. Picking one: the number it had in that list, given to a second run
    $Wanted = [array]::IndexOf($Fonts, "Consolas") + 1
    $null = Invoke-Font @("$Pick", "$Wanted")

    # Written for Terminal to read, and Terminal will not read a byte-order mark:
    # Set-Content -Encoding Utf8 writes one, and every fragment this repository
    # wrote until it was measured began with one - so none of them was ever
    # applied. The icon, the font and the colours all went into a file Terminal
    # quietly ignored. WSL's own fragment starts with a brace, and so must ours.
    $Bytes = [System.IO.File]::ReadAllBytes($OurFragment)
    Check "the fragment starts with a brace, not a mark" ([char]$Bytes[0]) "{"

    $Written = Get-Content $OurFragment -Raw | ConvertFrom-Json
    Check "the font is written into our profile" $Written.profiles[0].font.face "Consolas"
    Check "  ... under the guid Terminal knows" $Written.profiles[0].updates "{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e6f}"
    Check "  ... and the look around it is kept" ($Written.profiles[0].PSObject.Properties.Name -contains "colorScheme") $true

    $Saved = Get-Content $Recipe -Raw | ConvertFrom-Json
    Check "and into the instance's own file" $Saved.Font "Consolas"
    Check "which is still the instance's" $Saved.Name $FakeName

    # 3. The way it is reached: the theme menu asks which instance, hands over to
    # this command, and is drawn again when it is done. Answers: the instance,
    # "font", Escape on the font list, Escape here.
    $Preference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Themed = @("$Pick", "2", "0", "0") | & powershell -NoProfile -File (Join-Path $PSScriptRoot "..\scripts\theme.ps1") 2>&1
    } finally {
        $ErrorActionPreference = $Preference
    }
    Check "theme hands over to the font command" (@($Themed | Where-Object { "$_".Contains("Font of '$FakeName'") }).Count -gt 0) $true
    # Twice: once to start with, and once more when the theme menu is left -
    # Escape goes back up to the list, so that another instance can be picked.
    Check "and the list comes back when the menu is left" (@($Themed | Where-Object { "$_".Contains("Our Instances") }).Count) 2
    Check "and the menu comes back when it is done" (@($Themed | Where-Object { "$_".Contains("Theme of '$FakeName'") }).Count) 2
} finally {
    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $WslFragment -Force -ErrorAction SilentlyContinue
    if (-not $OurFragmentExisted) { Remove-Item $OurFragment -Force -ErrorAction SilentlyContinue }
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures

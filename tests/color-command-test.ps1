# Drives `color` - the command behind `.\wsl.ps1 theme` - the way a script would:
# the numbered prompt, answers on standard input, no console anywhere.
#
# The instance it works on exists for the length of the test: a registry key of
# its own, a folder carrying the marker, the WSL fragment a profile is looked up
# by, and the profile this repository writes, naming a scheme of the test's own -
# so that one name in the list is certainly there, whatever the machine has.
#
# What is checked is what the command is for: the schemes this machine can wear
# are listed - the one an instance is already using among them - the scheme in
# use is marked, and picking one writes it into the profile this repository owns
# and into the instance's own file. The list is read from a first run that
# cancels, so the number given to the second one was really in it.
#
# It needs no instance, no console and no Docker Desktop.
#
# Usage:  powershell -NoProfile -File tests\color-command-test.ps1

$ErrorActionPreference = "Stop"

# For Get-Distros and the marker test: the list the command itself builds.
. (Join-Path $PSScriptRoot "..\scripts\instance.ps1")

$ColorScript = Join-Path $PSScriptRoot "..\scripts\color.ps1"
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("color-command-test-" + [Guid]::NewGuid().ToString("N"))
$FakeName = "color-command-test"
$FakeFolder = Join-Path $Tmp "instance"
$Recipe = Join-Path $FakeFolder "instance.json"
$Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e5f}"

$WslFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\Microsoft.WSL\{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e7f}.json"
$OurFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-datascience-template\$FakeName.json"
$OurFragmentExisted = Test-Path $OurFragment

# The scheme the test puts in the instance's profile before it starts: whatever
# else the machine offers, this one is in the list.
$Planted = "Test Scheme Alpha"

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

function Invoke-Color {
    param([string[]]$Answers)

    $Preference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Lines = $Answers | & powershell -NoProfile -File $ColorScript 2>&1
    } finally {
        $ErrorActionPreference = $Preference
    }
    return $Lines
}

# The rows of the numbered list, read from the title of the colour menu down: the
# instance list the command asks about first is drawn the same way, and its rows
# are not schemes.
function Get-ListedSchemes {
    param([object[]]$Lines)

    $Rows = @()
    $Inside = $false
    foreach ($Line in $Lines) {
        if ("$Line" -like "Colours of '*'") { $Inside = $true; continue }
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
            "guid": "{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e7f}"
        }
    ]
}
"@

    New-Item -ItemType Directory -Path (Split-Path -Parent $OurFragment) -Force | Out-Null
    Set-Content -Path $OurFragment -Encoding Utf8 -Value @"
{
    "profiles": [
        {
            "updates": "{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e7f}",
            "colorScheme": "$Planted"
        }
    ]
}
"@

    $All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.BasePath } | Sort-Object Name)
    $Pick = [array]::IndexOf(@($All.Name), $FakeName) + 1
    Check "the test's instance is in the list" ($Pick -ge 1) $true

    # 1. The list, read off a run that cancels
    $Out = Invoke-Color @("$Pick", "0")
    $Schemes = @(Get-ListedSchemes $Out)
    Check "the schemes are listed" ($Schemes.Count -ge 1) $true

    # And every row has the same width, the mark's column included. The names are
    # padded inside the colours, so the painted block of each row ends at the same
    # column; without it the list is bars of different lengths - a barcode, not a
    # list.
    $Widths = @()
    $Inside = $false
    foreach ($Line in $Out) {
        if ("$Line" -like "Colours of '*'") { $Inside = $true; continue }
        if (-not $Inside) { continue }
        if ("$Line" -match '^\s*0\.') { break }
        if ("$Line" -match '^\s*\d+\.\s+(.*)$') { $Widths += $Matches[1].Length }
    }
    Check "every row is the same width" (@($Widths | Sort-Object -Unique).Count) 1
    Check "the one the instance wears is in it" ($Schemes -contains $Planted) $true
    Check "and it is marked as the one in use" (@($Out | Where-Object { "$_" -like "*(current)*" }).Count -gt 0) $true
    Check "cancelling applied nothing" ((Get-Content $OurFragment -Raw | ConvertFrom-Json).profiles[0].colorScheme) $Planted

    # 2. Picking one: the number it had in that list, given to a second run. The
    # list is the machine's, so the scheme picked is whichever is number one -
    # and the run says so either way.
    $null = Invoke-Color @("$Pick", "1")

    $Written = Get-Content $OurFragment -Raw | ConvertFrom-Json
    Check "the scheme is written into our profile" $Written.profiles[0].colorScheme $Schemes[0]
    Check "  ... under the guid Terminal knows" $Written.profiles[0].updates "{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e7f}"
    Check "  ... and the font is kept beside it" ($Written.profiles[0].font.face -ne $null) $true

    $Saved = Get-Content $Recipe -Raw | ConvertFrom-Json
    Check "and into the instance's own file" $Saved.ColorScheme $Schemes[0]
    Check "which is still the instance's" $Saved.Name $FakeName
} finally {
    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $WslFragment -Force -ErrorAction SilentlyContinue
    if (-not $OurFragmentExisted) { Remove-Item $OurFragment -Force -ErrorAction SilentlyContinue }
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures

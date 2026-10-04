# Drives the archive family - archive, restore, duplicate - the way a script
# would: the numbered prompt, answers on standard input, no console anywhere,
# and the same stand-in wsl.exe as the lifecycle suite - logging every call,
# writing the file an export would write and the folder an import would create.
#
# The instance it works on exists for the length of the test: a registry key of
# its own, a folder carrying the marker, the disk, the icon and the look
# (instance.json, recipe included) a real instance would carry. The commands'
# root is followed the way they compute it - D:\WSL when there is a D:, the
# profile otherwise, redirected into the test's folder - and LOCALAPPDATA and
# APPDATA are redirected too, so the archives, the install folders and the
# Windows Terminal fragments all land in the test's world, never in the real
# ones: a root that already exists is refused, not touched. Everything the
# test made is taken back out at the end.
#
# What is checked: for `archive`, the export and its format, the tar written,
# the look saved beside it - recipe included - a running instance stopped
# before the export and left as it was found; for `restore`, the import at
# version 2, the marker, the recipe and the icon coming back, the fragment
# re-applied under the guid WSL gave the instance; for `duplicate`, the export
# to a temporary tar, the import at the source's own version, the temporary
# removed, the marker, the look on the copy, and the source restarted only
# when it was running.
#
# It needs no instance, no console and no Docker Desktop.
#
# Usage:  pwsh -NoProfile -File tests\archive-command-test.ps1

$ErrorActionPreference = "Stop"

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("archive-command-test-" + [Guid]::NewGuid().ToString("N"))
$FakeName = "archive-command-test"
$FakeFolder = Join-Path $Tmp "instance"
$Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\{4c1d2e3f-6a7b-4c8d-9e0f-1a2b3c4d5e6f}"
$Log = Join-Path $Tmp "wsl-calls.log"

# The commands work under one root: D:\WSL when there is a D:, the profile
# otherwise - the rule the family follows, so the suite follows it too and its
# expectations land where the children write. The profile is redirected anyway,
# for the machines without a D:. A root that already exists is refused: this
# suite writes under it and empties it again, not what a real one deserves.
$env:USERPROFILE = $Tmp
$env:LOCALAPPDATA = Join-Path $Tmp "LocalAppData"
$env:APPDATA = Join-Path $Tmp "AppData"
New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$Root = if (Test-Path "D:\") { "D:\WSL" } else { Join-Path $Tmp "WSL" }
if (Test-Path $Root) {
    throw "$Root already exists - this suite writes under it and leaves it empty again; refusing to touch one that is already there"
}

# For Get-Distros and the marker test: the list the commands themselves build.
. (Join-Path $PSScriptRoot "..\scripts\instance.ps1")

$ArchiveScript = Join-Path $PSScriptRoot "..\scripts\archive.ps1"
$RestoreScript = Join-Path $PSScriptRoot "..\scripts\restore.ps1"
$DuplicateScript = Join-Path $PSScriptRoot "..\scripts\duplicate.ps1"
# Child processes follow the engine this suite runs under, so a pass under 7
# tests the scripts under 7.
$Engine = if ($PSVersionTable.PSEdition -eq "Core") { "pwsh" } else { "powershell" }

# The stand-in, ahead of any wsl.exe for every child this suite starts: a real
# binary of that name, compiled here from tests\fake-wsl\wsl.cs - the scripts
# call `wsl.exe` with its extension, so only a binary answers to it, never a
# script.
$FakeDir = Join-Path $Tmp "fake-wsl"
New-Item -ItemType Directory -Path $FakeDir -Force | Out-Null
$Csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $Csc)) { $Csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe" }
& $Csc /nologo /out:"$(Join-Path $FakeDir 'wsl.exe')" (Join-Path $PSScriptRoot "fake-wsl\wsl.cs")
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $FakeDir "wsl.exe"))) {
    throw "the stand-in wsl.exe could not be compiled"
}
$env:PATH = $FakeDir + [IO.Path]::PathSeparator + $env:PATH
$env:FAKE_WSL_LOG = $Log
$env:FAKE_WSL_INSTANCE = $FakeName

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

# The child's own exit code, beside its output: a refusal is a result too.
$script:ChildExit = 0

function Invoke-Child {
    param([string]$Script, [string[]]$Answers)

    $Preference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Lines = $Answers | & $Engine -NoProfile -File $Script 2>&1
        $script:ChildExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $Preference
    }
    return $Lines
}

# What the stand-in was asked, in order - its log, the arguments line by line.
# The raw command lines stay out: the checks below speak of arguments.
function Get-Calls {
    if (-not (Test-Path $Log)) { return @() }
    return @(Get-Content $Log | Where-Object { $_ -and $_ -notlike "raw:*" })
}

# What a step above should have written, read back - or an empty string, so a
# missing file fails its check instead of stopping the suite.
function Get-FileText {
    param([string]$Path)
    if (Test-Path $Path) { return (Get-Content $Path -Raw) }
    return ""
}

# The instance: a folder carrying the marker, the disk, the icon, and a look
# with its recipe - the voyage items all start here.
New-Item -ItemType Directory -Path $FakeFolder -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $FakeFolder ".wsl-stack") -Force | Out-Null
Set-Content -Path (Join-Path $FakeFolder "ext4.vhdx") -Value "fake-disk" -NoNewline
Set-Content -Path (Join-Path $FakeFolder "terminal-icon.png") -Value "fake-icon" -NoNewline
@{
    Name          = $FakeName
    Font          = "MesloLGS NF"
    ColorScheme   = "One Half Dark"
    IconFrom      = (Join-Path $FakeFolder "terminal-icon.png")
    IconText      = "TR"
    IconTop       = "#010203"
    IconBottom    = "#040506"
    IconTextColor = "#070809"
} | ConvertTo-Json | Set-Content -Path (Join-Path $FakeFolder "instance.json") -Encoding Utf8

# The WSL fragments a real import would leave behind: the guid Windows
# Terminal knows a profile by. Without one the look is not re-applied, and
# that re-application is what the voyage is about.
$WslFragments = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\Microsoft.WSL"
New-Item -ItemType Directory -Path $WslFragments -Force | Out-Null
@{
    profiles = @(
        @{ name = "restored-one"; guid = "{11111111-2222-3333-4444-555555555555}" },
        @{ name = "copied-one";   guid = "{66666666-7777-8888-9999-000000000000}" }
    )
} | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $WslFragments "planted.json") -Encoding Utf8

try {
    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path $Key -Force | Out-Null
    Set-ItemProperty -Path $Key -Name DistributionName -Value $FakeName
    Set-ItemProperty -Path $Key -Name BasePath -Value $FakeFolder
    # The WSL version the source runs as: the copy must import at it, so 1 -
    # 2 would pass even if the code read nothing from the source.
    Set-ItemProperty -Path $Key -Name Version -Value 1

    # Which number our instance is in the list the command draws - worked out
    # with the same code, so the answer is right whatever else is installed.
    $All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.Path } | Sort-Object Name)
    $Pick = [array]::IndexOf(@($All.Name), $FakeName) + 1
    Check "the test's instance is in the list" ($Pick -ge 1) $true

    $ArchiveDir = Join-Path $Root "archives\$FakeName"
    $TarPath = Join-Path $ArchiveDir "$FakeName.tar.gz"
    $Fragments = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-stack"

    # 0. restore first, with no archive anywhere: it says how to make one
    # instead of printing a list over nothing.
    $Out = Invoke-Child -Script $RestoreScript -Answers @("")
    Check "restore with no archives says where they go" (@($Out | Where-Object { "$_".Contains("There are no archives") }).Count -gt 0) $true
    Check "and ends on one" $script:ChildExit 1

    # 1. archive: the export is asked for by name and format, and the look is
    # saved beside the tar, recipe included - a stopped instance is left
    # stopped, the default it offers.
    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    $Out = Invoke-Child -Script $ArchiveScript -Answers @("$Pick", "", "3")
    Check "archive exports the instance picked, as a tar.gz" (@(Get-Calls | Where-Object { $_ -eq "--export $FakeName $TarPath --format tar.gz" }).Count) 1
    Check "and says the backup is written" (@($Out | Where-Object { "$_".Contains("Backup of '$FakeName' written") }).Count -gt 0) $true
    Check "and leaves the instance stopped, the default of a stopped one" (@($Out | Where-Object { "$_".Contains("left stopped") }).Count -gt 0) $true
    Check "and ends on zero" $script:ChildExit 0

    $Raw = Get-FileText (Join-Path $ArchiveDir "instance.json")
    $Saved = if ($Raw) { $Raw | ConvertFrom-Json } else { $null }
    Check "the archive carries the icon recipe" "$($Saved.IconText)/$($Saved.IconTop)/$($Saved.IconBottom)/$($Saved.IconTextColor)" "TR/#010203/#040506/#070809"
    Check "and names the archive after the instance" "$($Saved.Name)" $FakeName
    Check "and the icon itself waits beside the tar" (Test-Path (Join-Path $ArchiveDir "terminal-icon.png")) $true

    # The same on a running instance: asked about, stopped only on the answer,
    # the stop before the export, and back up after it - the default a running
    # instance offers. The second archive's name is typed, not proposed.
    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    Add-Content -Path $Log -Value "-d $FakeName --exec /bin/true"
    $Out = Invoke-Child -Script $ArchiveScript -Answers @("$Pick", "", "second-backup", "1")
    $Calls = Get-Calls
    $SecondTar = Join-Path $Root "archives\second-backup\second-backup.tar.gz"
    Check "a running instance is stopped, on the answer" (@($Calls | Where-Object { $_ -eq "--terminate $FakeName" }).Count) 1
    Check "and the stop comes before the export" ([array]::IndexOf($Calls, "--terminate $FakeName") -lt [array]::IndexOf($Calls, "--export $FakeName $SecondTar --format tar.gz")) $true
    Check "and a typed name names the archive" (Test-Path $SecondTar) $true
    Check "and it comes back up after the export" ([array]::IndexOf($Calls, "--export $FakeName $SecondTar --format tar.gz") -lt [array]::LastIndexOf($Calls, "-d $FakeName --exec /bin/true")) $true
    Check "and ends on zero" $script:ChildExit 0

    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    Add-Content -Path $Log -Value "-d $FakeName --exec /bin/true"
    $Out = Invoke-Child -Script $ArchiveScript -Answers @("$Pick", "n")
    Check "answered n: nothing is exported" (@(Get-Calls | Where-Object { $_ -like "--export*" }).Count) 0
    Check "and nothing was modified" (@($Out | Where-Object { "$_".Contains("Operation cancelled by user") }).Count -gt 0) $true

    # One archive left from here on: the restore scenarios pick a known one.
    Remove-Item -Recurse -Force (Join-Path $Root "archives\second-backup") -ErrorAction SilentlyContinue

    # 2. restore: the tar goes in at version 2, the marker says who wrote it,
    # and the look comes back - recipe, icon copied into the instance, fragment
    # re-applied under the guid WSL gave the instance.
    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    $Out = Invoke-Child -Script $RestoreScript -Answers @("1", "restored-one")
    $Install = Join-Path $Root "restored-one"
    Check "restore imports the tar it picked, as version 2" (@(Get-Calls | Where-Object { $_ -eq "--import restored-one $Install $TarPath --version 2" }).Count) 1
    Check "and says the instance came back" (@($Out | Where-Object { "$_".Contains("'restored-one' restored from an archive") }).Count -gt 0) $true
    $Raw = Get-FileText (Join-Path $Install ".wsl-stack")
    $Marker = if ($Raw) { ($Raw | ConvertFrom-Json).by } else { "" }
    Check "and the marker is written, credited to restore" "$Marker" "restore"
    Check "and ends on zero" $script:ChildExit 0

    $Raw = Get-FileText (Join-Path $Install "instance.json")
    $Restored = if ($Raw) { $Raw | ConvertFrom-Json } else { $null }
    Check "and the recipe comes back" "$($Restored.IconText)/$($Restored.IconTop)/$($Restored.IconBottom)/$($Restored.IconTextColor)" "TR/#010203/#040506/#070809"
    Check "and the icon is copied into the instance" (Test-Path (Join-Path $Install "terminal-icon.png")) $true
    Check "and the file points at the instance's own icon" "$($Restored.IconFrom)" (Join-Path $Install "terminal-icon.png")
    Check "and the look is reported re-applied" (@($Out | Where-Object { "$_".Contains("icon re-applied") }).Count -gt 0) $true
    Check "and the Terminal fragment carries the guid WSL gave it" ("$(Get-FileText (Join-Path $Fragments "restored-one.json"))".Contains("{11111111-2222-3333-4444-555555555555}")) $true

    # A name already registered, then a name whose folder exists: refused, said,
    # nothing imported. An empty answer cancels, an unusable name is refused.
    $Out = Invoke-Child -Script $RestoreScript -Answers @("1", "$FakeName")
    Check "restore refuses a name already registered" (@($Out | Where-Object { "$_".Contains("already exists") }).Count -gt 0) $true
    Check "and ends on one" $script:ChildExit 1

    $Out = Invoke-Child -Script $RestoreScript -Answers @("1", "restored-one")
    Check "restore refuses a folder already taken" (@($Out | Where-Object { "$_".Contains("A folder with that name already exists") }).Count -gt 0) $true
    Check "and ends on one" $script:ChildExit 1

    $Out = Invoke-Child -Script $RestoreScript -Answers @("1", "")
    Check "an empty name cancels the restore" (@($Out | Where-Object { "$_".Contains("Operation cancelled by user") }).Count -gt 0) $true
    Check "and ends on zero" $script:ChildExit 0

    $Out = Invoke-Child -Script $RestoreScript -Answers @("1", "not a name!")
    Check "an unusable name is refused" (@($Out | Where-Object { "$_".Contains("not usable as an instance name") }).Count -gt 0) $true
    Check "and ends on one" $script:ChildExit 1

    # 3. duplicate: an export to a temporary tar, an import of the copy at the
    # source's own version, the temporary removed, and the look captured before
    # the export landing on the copy.
    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    $Out = Invoke-Child -Script $DuplicateScript -Answers @("$Pick", "copied-one")
    $CopyDir = Join-Path $Root "copied-one"
    $TempTar = Join-Path $Root "copied-one-export.tar.gz"
    $Calls = Get-Calls
    Check "duplicate exports the source to a temporary tar" (@($Calls | Where-Object { $_ -eq "--export $FakeName $TempTar --format tar.gz" }).Count) 1
    Check "and imports the copy at the source's own version" (@($Calls | Where-Object { $_ -eq "--import copied-one $CopyDir $TempTar --version 1" }).Count) 1
    Check "and the temporary tar is removed" (Test-Path $TempTar) $false
    Check "and says what it made" (@($Out | Where-Object { "$_".Contains("'copied-one' is a copy of '$FakeName'") }).Count -gt 0) $true
    $Raw = Get-FileText (Join-Path $CopyDir ".wsl-stack")
    $Marker = if ($Raw) { ($Raw | ConvertFrom-Json).by } else { "" }
    Check "and the marker is written, credited to duplicate" "$Marker" "duplicate"
    Check "and ends on zero" $script:ChildExit 0

    $Raw = Get-FileText (Join-Path $CopyDir "instance.json")
    $Copy = if ($Raw) { $Raw | ConvertFrom-Json } else { $null }
    Check "and the recipe travels to the copy" "$($Copy.IconText)/$($Copy.IconTop)/$($Copy.IconBottom)/$($Copy.IconTextColor)" "TR/#010203/#040506/#070809"
    Check "and the copy's icon points at its own folder" "$($Copy.IconFrom)" (Join-Path $CopyDir "terminal-icon.png")
    Check "and the copy gets its own Terminal fragment" ("$(Get-FileText (Join-Path $Fragments "copied-one.json"))".Contains("{66666666-7777-8888-9999-000000000000}")) $true

    # A running source: asked, stopped on the answer, restarted once the copy
    # is registered - never before.
    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    Add-Content -Path $Log -Value "-d $FakeName --exec /bin/true"
    $Out = Invoke-Child -Script $DuplicateScript -Answers @("$Pick", "copied-two", "")
    $Calls = Get-Calls
    $Copy2Dir = Join-Path $Root "copied-two"
    $TempTar2 = Join-Path $Root "copied-two-export.tar.gz"
    Check "a running source is stopped, on the answer" (@($Calls | Where-Object { $_ -eq "--terminate $FakeName" }).Count) 1
    Check "and the stop comes before the export" ([array]::IndexOf($Calls, "--terminate $FakeName") -lt [array]::IndexOf($Calls, "--export $FakeName $TempTar2 --format tar.gz")) $true
    Check "and the copy is registered once the source is read" (@($Calls | Where-Object { $_ -eq "--import copied-two $Copy2Dir $TempTar2 --version 1" }).Count) 1
    Check "and the source comes back after that" ([array]::IndexOf($Calls, "--import copied-two $Copy2Dir $TempTar2 --version 1") -lt [array]::LastIndexOf($Calls, "-d $FakeName --exec /bin/true")) $true
    Check "and says it is running again" (@($Out | Where-Object { "$_".Contains("'$FakeName' is running again") }).Count -gt 0) $true
    Check "and the second temporary tar is removed too" (Test-Path $TempTar2) $false

    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    Add-Content -Path $Log -Value "-d $FakeName --exec /bin/true"
    $Out = Invoke-Child -Script $DuplicateScript -Answers @("$Pick", "copied-three", "n")
    Check "answered n: the source is not stopped" (@(Get-Calls | Where-Object { $_ -like "--terminate*" }).Count) 0
    Check "and nothing was modified" (@($Out | Where-Object { "$_".Contains("Operation cancelled by user") }).Count -gt 0) $true

    $Out = Invoke-Child -Script $DuplicateScript -Answers @("$Pick", "$FakeName")
    Check "duplicate refuses a name already taken" (@($Out | Where-Object { "$_".Contains("already exists") }).Count -gt 0) $true
    Check "and ends on one" $script:ChildExit 1
} finally {
    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $Root -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures

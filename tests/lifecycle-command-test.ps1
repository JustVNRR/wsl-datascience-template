# Drives `start` and `restart` the way a script would: the numbered prompt,
# answers on standard input, no console anywhere, and a stand-in wsl.exe ahead
# on the PATH (tests\fake-wsl\) that notes every call and answers from its own
# log - a distribution counts as running once a boot command has gone through.
#
# The instance it works on exists for the length of the test: a registry key of
# its own, a folder carrying the marker, and a name of its own. The key is
# taken back out at the end. Nothing real is started or stopped: what is
# checked is the command emitted, its order, and what is said.
#
# What is checked for `start`: the boot names the instance picked, the news is
# said, and cancelling boots nothing. For `restart`: the stop comes before the
# boot, and the news comes after both.
#
# It needs no instance, no console and no Docker Desktop.
#
# Usage:  pwsh -NoProfile -File tests\lifecycle-command-test.ps1

$ErrorActionPreference = "Stop"

# For Get-Distros and the marker test: the list the command itself builds.
. (Join-Path $PSScriptRoot "..\scripts\instance.ps1")

$StartScript = Join-Path $PSScriptRoot "..\scripts\start.ps1"
$RestartScript = Join-Path $PSScriptRoot "..\scripts\restart.ps1"
# Child processes follow the engine this suite runs under, so a pass under 7
# tests the scripts under 7.
$Engine = if ($PSVersionTable.PSEdition -eq "Core") { "pwsh" } else { "powershell" }
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("lifecycle-command-test-" + [Guid]::NewGuid().ToString("N"))
$FakeName = "lifecycle-command-test"
$FakeFolder = Join-Path $Tmp "instance"
$Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e5f}"
$Log = Join-Path $Tmp "wsl-calls.log"

# The stand-in, ahead of the real wsl.exe for every child this suite starts.
# Its answers come from the log it writes: an empty log is a machine where
# nothing runs, a boot line makes the instance a running one.
$env:PATH = (Join-Path $PSScriptRoot "fake-wsl") + [IO.Path]::PathSeparator + $env:PATH
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

# What the stand-in was asked, in order - its log, line by line.
function Get-Calls {
    if (-not (Test-Path $Log)) { return @() }
    return @(Get-Content $Log | Where-Object { $_ })
}

New-Item -ItemType Directory -Path $FakeFolder -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $FakeFolder ".wsl-stack") -Force | Out-Null

try {
    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path $Key -Force | Out-Null
    Set-ItemProperty -Path $Key -Name DistributionName -Value $FakeName
    Set-ItemProperty -Path $Key -Name BasePath -Value $FakeFolder

    # Which number our instance is in the list the command draws - worked out
    # with the same code, so the answer is right whatever else is installed.
    $All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.Path } | Sort-Object Name)
    $Pick = [array]::IndexOf(@($All.Name), $FakeName) + 1
    Check "the test's instance is in the list" ($Pick -ge 1) $true

    # 1. start: the boot names the instance picked, and the command says so.
    # The log starts empty, so nothing runs and the instance is there to pick.
    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    $Out = Invoke-Child -Script $StartScript -Answers @("$Pick")
    Check "start boots the instance picked, by name" `
        (@(Get-Calls | Where-Object { $_ -eq "-d $FakeName --exec /bin/true" }).Count) 1
    Check "and says it is running" (@($Out | Where-Object { "$_".Contains("'$FakeName' is running") }).Count -gt 0) $true
    Check "and ends on zero" $script:ChildExit 0

    # 2. Escape is not a boot: the number 0 is the way out, and nothing is
    # asked of WSL.
    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    $Out = Invoke-Child -Script $StartScript -Answers @("0")
    Check "cancelling boots nothing" (@(Get-Calls | Where-Object { $_ -like "*--exec*" }).Count) 0
    Check "and says nothing was modified" (@($Out | Where-Object { "$_".Contains("Operation cancelled by user") }).Count -gt 0) $true
    Check "and ends on zero" $script:ChildExit 0

    # 3. restart: the stop comes first, the boot after it, and the news last.
    # A boot in the log is what an earlier start would have left; the instance
    # is one of the running ones, so it is there to pick.
    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    Add-Content -Path $Log -Value "-d $FakeName --exec /bin/true"
    $Out = Invoke-Child -Script $RestartScript -Answers @("$Pick", "")
    $Calls = Get-Calls
    Check "restart stops the instance first" (@($Calls | Where-Object { $_ -eq "--terminate $FakeName" }).Count) 1
    Check "and boots it after the stop" `
        ($Calls.IndexOf("--terminate $FakeName") -lt $Calls.LastIndexOf("-d $FakeName --exec /bin/true")) $true
    Check "and says it is running again" (@($Out | Where-Object { "$_".Contains("'$FakeName' is running again") }).Count -gt 0) $true
    Check "and ends on zero" $script:ChildExit 0
} finally {
    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures

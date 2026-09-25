# Drives the ask/apply pair of scripts\packs.ps1 with no instance and no
# terminal.
#
#   Select-Packs   is answered on standard input: with no console the numbered
#                  prompt is what runs, and it reads its answers from there.
#   Invoke-PackApply  has every move intercepted. The stand-in for
#                  Invoke-InInstance is the one place where a pack touches the
#                  instance - copy its folder in, run one of its scripts, take
#                  the folder out, travel the cleanup - so recording the calls
#                  there records the ORDER, which is the whole design: the
#                  newcomer's folder is placed BEFORE a remove.sh asks its
#                  question, so a shared package is left where it is.
#
# Run it with tests\packs-select-test.answers on standard input, which holds the
# answers one per line, in the order they are read - and in these exact counts,
# because each scenario consumes its own:
#   1, v, (empty)   one box ticked -> it and its requirement, requirement first
#   2, v, (empty)   the installed box unticked -> one removal
#   0               cancelled
#   v               nothing checked, nothing installed: ONE answer, because
#                   there is no list to confirm - which is the point of it
#   1, v, n         the confirmation answered no
#   v, (empty)      pre-checked, nothing installed
#   v               a pack installed here that this checkout does not carry:
#                   ONE answer, for the same reason as above
#   3, v, (empty)   a requirement already installed -> only the ticked one travels
#   3, v, (empty)   the claimant unticked -> it and the invisible one leave
#   3, v, (empty)   a second claimant installed -> only the ticked one leaves
#   v               an invisible pack among the pre-checked ones: ONE answer,
#                   because it has no box and nothing else was ticked
#
#   powershell -File tests\packs-select-test.ps1 < tests\packs-select-test.answers
#
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\scripts\instance.ps1")

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

# The shape Get-AvailablePacks hands back, declarations included: gcp and python
# require devops, and devops is the invisible one - it is in no list, and it
# travels with what requires it. Its row is absent from the checklist, which is
# also what every numbered answer below counts on: were it offered, the
# numbering would shift and every scenario would answer about the wrong pack.
$Available = @(
    [PSCustomObject]@{ Name = "gcp";    Path = "X:\packs\gcp";    Description = "Google Cloud CLI";  Requires = @("devops"); Visible = $true },
    [PSCustomObject]@{ Name = "vision"; Path = "X:\packs\vision"; Description = "Image and OCR tools"; Requires = @();    Visible = $true },
    [PSCustomObject]@{ Name = "python"; Path = "X:\packs\python"; Description = "Python toolchain";  Requires = @("devops"); Visible = $true },
    [PSCustomObject]@{ Name = "devops"; Path = "X:\packs\devops"; Description = "Project targets";   Requires = @();    Visible = $false }
)

Write-Output "--- Select-Packs: what the checklist means ---"

# 1. An installed pack arrives checked; ticking one more box adds it - with what
#    it requires, and before it: gcp requires devops, and a pack is installed on
#    top of what it needs.
$Selection = Select-Packs -Title "T" -Available $Available -Installed @("vision")
Check "one box ticked -> its requirement comes first, then it" `
    ((($Selection.ToAdd | ForEach-Object { $_.Name }) -join ",") + " / " + ($Selection.ToRemove -join ",")) "devops,gcp / "

# 2. Unticking what is installed, with nothing else ticked, is a removal - and
#    ONLY a removal. The first version of this shipped reading the additions off
#    the available packs instead of the ticked ones, so a run installed the pack
#    nobody had asked for.
$Selection = Select-Packs -Title "T" -Available $Available -Installed @("vision")
Check "unticking -> the pack leaves, the rest is NOT added" `
    ((($Selection.ToAdd | ForEach-Object { $_.Name }) -join ",") + " / " + ($Selection.ToRemove -join ",")) " / vision"

# 3. Cancel is cancel.
$Selection = Select-Packs -Title "T" -Available $Available -Installed @("vision")
Check "cancelled -> nothing at all" ($null -eq $Selection) "True"

# 4. Nothing checked and nothing installed is an ANSWER, not a cancellation: the
#    two lists come back empty and the caller decides what that means. (.Count
#    answers 0 for $null too, so the $null test is the sharp one; the second
#    check is what proves the list itself came back.)
$Selection = Select-Packs -Title "T" -Available $Available -Installed @()
Check "empty checklist is not a cancellation" ($null -eq $Selection) "False"
Check "  ... and both lists are empty" `
    ("$($Selection.ToAdd.Count)$($Selection.ToRemove.Count)") "00"

# 5. "n" at the one confirmation is a cancellation too.
$Selection = Select-Packs -Title "T" -Available $Available -Installed @("vision")
Check "answered n -> nothing at all" ($null -eq $Selection) "True"

# 6. Two different facts. What the instance HAS is not what arrives ticked: at
#    build time the new instance has no pack yet (nothing can be removed), while
#    the ticked boxes are the ones its predecessor carried.
$Selection = Select-Packs -Title "T" -Available $Available -Installed @() -Checked @("vision")
Check "pre-checked is not installed" `
    ((($Selection.ToAdd | ForEach-Object { $_.Name }) -join ",") + " / " + ($Selection.ToRemove -join ",")) "vision / "

# 7. A pack installed in the instance that THIS checkout does not carry - one
#    copied in by hand, one from another checkout, one since removed from the
#    repository - is not in the checklist, so nobody can have unchecked it. It
#    must be left alone. The first version read "installed and not ticked" and
#    removed it without ever showing it.
$Selection = Select-Packs -Title "T" -Available $Available -Installed @("vision", "foreign")
Check "a pack this checkout does not carry is left alone" ($Selection.ToRemove -join ",") ""
Check "  ... and the answer is still an answer, not a cancellation" ($null -eq $Selection) "False"

Write-Output ""
Write-Output "--- Select-Packs: the packs nobody picks ---"

# 8. What the instance already carries is not installed a second time. devops is
#    there, python is ticked, and python travels alone: the pack that is already
#    in place is not copied over itself and its install.sh does not run again.
#    Installing gcp on an instance that has carried python for months is that
#    same case - and devops stays, held by the arrival of the same run.
$Selection = Select-Packs -Title "T" -Available $Available -Installed @("devops")
Check "a requirement already installed is not installed again" `
    ((($Selection.ToAdd | ForEach-Object { $_.Name }) -join ",") + " / " + ($Selection.ToRemove -join ",")) "python / "

# 9. An invisible pack has no row, so nobody can untick it - it leaves when the
#    last pack that requires it does, and in the same answer (devops is python's
#    requirement; the scenario starts from that pair installed).
$Selection = Select-Packs -Title "T" -Available $Available -Installed @("python", "devops")
Check "the last claimant leaves -> the invisible one goes too" `
    ((($Selection.ToAdd | ForEach-Object { $_.Name }) -join ",") + " / " + ($Selection.ToRemove -join ",")) " / python,devops"

# 10. ... and it stays while an installed pack still requires it. That is the
#     whole reason it is not offered: another claimant is still there to hold it.
$Selection = Select-Packs -Title "T" -Available $Available -Installed @("python", "gcp", "devops")
Check "another claimant holds it -> it stays" `
    ((($Selection.ToAdd | ForEach-Object { $_.Name }) -join ",") + " / " + ($Selection.ToRemove -join ",")) " / python"

# 11. What an instance carried is not what the checklist shows: a predecessor
#     that had an invisible pack must not bring it back through a tick nobody
#     can see. It arrives with the pack that requires it, or not at all.
$Selection = Select-Packs -Title "T" -Available $Available -Installed @() -Checked @("devops")
Check "a checked invisible pack installs nothing" ($null -eq $Selection) "False"
Check "  ... and both lists are empty" ("$($Selection.ToAdd.Count)$($Selection.ToRemove.Count)") "00"

Write-Output ""
Write-Output "--- Invoke-PackApply: the order, and where a failure stops ---"

# The stand-in speaks on purpose. The functions below hand a value back, and a
# value must not carry the output of what was run to produce it: this is what
# made a pack's install go silent, with apt's lines captured into the variable
# that was holding the answer. Every check that reads a returned value is
# therefore also a check on where the output went.
$script:Calls = @()
$script:FailCommand = ""
function Invoke-InInstance {
    param([string]$DistroName, [string[]]$Command, [string]$WorkingDirectory, [ref]$ExitCode, [switch]$Quiet)
    $Line = ($Command -join " ")
    $Where = if ($WorkingDirectory) { $WorkingDirectory } else { "~" }
    $script:Calls += "$Where :: $Line"
    if (-not $Quiet) { Write-Output "INSTANCE-SAYS: $Line" }
    if ($script:FailCommand -and $Line -like "$($script:FailCommand)*") { $ExitCode.Value = 1 }
    else { $ExitCode.Value = 0 }
}
function Reset { $script:Calls = @(); $script:FailCommand = "" }
function Commands { return @($script:Calls | ForEach-Object { ($_ -split " :: ", 2)[1] }) }

$Add = @([PSCustomObject]@{ Name = "fake-a"; Path = "X:\packs\fake-a"; Description = "d" })
$Directory = "/home/u/.config/packs"

Reset
$Result = Invoke-PackApply -DistroName "test" -PacksDirectory $Directory -ToAdd $Add -ToRemove @("fake-b")
Check "the newcomer is placed BEFORE the removal asks its question" `
    ($script:Calls.IndexOf("~ :: mkdir -p $Directory/fake-a") -lt
     $script:Calls.IndexOf("~ :: test -f $Directory/fake-b/remove.sh")) "True"
Check "the install comes after the removal" `
    ($script:Calls.IndexOf("$Directory/fake-a :: bash install.sh") -gt
     $script:Calls.IndexOf("~ :: rm -rf $Directory/fake-b")) "True"
Check "and the dependencies are taken back last" `
    ((@($script:Calls[-3..-1] | ForEach-Object { ($_ -split " :: ", 2)[1] }) -join " | ")) `
    "cp cleanup_orphans.sh /tmp/cleanup_orphans.sh | bash cleanup_orphans.sh | rm -f /tmp/cleanup_orphans.sh"
Check "nothing failed" ($null -eq $Result) "True"
Check "  ... and the instance's own words are not in the answer" ("$Result".Contains("INSTANCE-SAYS")) "False"

Reset
$Result = Invoke-PackApply -DistroName "test" -PacksDirectory $Directory -ToAdd $Add
Check "nothing to remove -> no removal, and no cleanup" `
    ((Commands) -join " | ") "mkdir -p $Directory/fake-a | cp -r . $Directory/fake-a/ | bash install.sh"

Reset
$script:FailCommand = "test -f"
$Result = Invoke-PackApply -DistroName "test" -PacksDirectory $Directory -ToRemove @("fake-b")
Check "no remove.sh -> the folder leaves, no script runs" `
    ((Commands) -join " | ") `
    "test -f $Directory/fake-b/remove.sh | rm -rf $Directory/fake-b | cp cleanup_orphans.sh /tmp/cleanup_orphans.sh | bash cleanup_orphans.sh | rm -f /tmp/cleanup_orphans.sh"

Reset
$script:FailCommand = "cp -r ."
$Result = Invoke-PackApply -DistroName "test" -PacksDirectory $Directory -ToAdd $Add -ToRemove @("fake-b")
Check "a failed copy names the pack that stopped it" "$($Result.Pack)/$($Result.ExitCode)" "fake-a/1"
Check "  ... and nothing else was touched" (@($script:Calls).Count) "2"

Reset
$script:FailCommand = "bash install.sh"
$Result = Invoke-PackApply -DistroName "test" -PacksDirectory $Directory -ToAdd $Add
Check "a failed install takes the folder back out" "$($Result.Pack)/$($Result.ExitCode)" "fake-a/1"
Check "  ... and the answer is one object, not that plus the output" (@($Result).Count) "1"
Check "  ... after the failure, not before" `
    ($script:Calls.IndexOf("~ :: rm -rf $Directory/fake-a") -gt
     $script:Calls.IndexOf("$Directory/fake-a :: bash install.sh")) "True"

Reset
$script:FailCommand = "bash remove.sh"
$Result = Invoke-PackApply -DistroName "test" -PacksDirectory $Directory -ToAdd $Add -ToRemove @("fake-b")
Check "a failed remove.sh names that pack" "$($Result.Pack)" "fake-b"
Check "  ... and nothing is installed after it" `
    (@($script:Calls | Where-Object { $_ -like "*bash install.sh*" }).Count) "0"
Check "  ... and its folder stays, it is still installed" `
    (@($script:Calls | Where-Object { $_ -like "*rm -rf*" }).Count) "0"

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures

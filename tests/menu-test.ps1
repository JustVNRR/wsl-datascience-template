# Drives scripts\menu.ps1 with a scripted keyboard: the arrow loop runs with no
# terminal in sight, which is the only way to test it - and it is what caught
# the bug that made every arrow stack one more copy of the list.
#
# It needs no console. The last checks use no -KeyReader at all, which is the
# no-console case: they read the numbered prompt's answers from standard input.
#
# Usage:  powershell -File tests\menu-test.ps1 < tests\menu-test.answers
#
# tests\menu-test.answers holds them, one per line, in the order they are read:
# 2, (empty), 1, 2, v, v, v, (empty). It is the ONLY copy - the CI redirects the
# same file rather than spelling the answers out again. A second copy is a copy
# that drifts, and that is exactly what happened once.
#
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\scripts\menu.ps1")

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

function Run-Menu {
    param([ConsoleKey[]]$Keys, [object[]]$Items, [scriptblock]$Label, [int]$Default = 0)
    $script:Queue = New-Object System.Collections.Queue
    foreach ($Key in $Keys) { $script:Queue.Enqueue($Key) }
    $Reader = { $script:Queue.Dequeue() }
    if ($Label) {
        return Select-FromList -Title "T" -Items $Items -Label $Label -KeyReader $Reader -DefaultIndex $Default
    }
    return Select-FromList -Title "T" -Items $Items -KeyReader $Reader -DefaultIndex $Default
}

$Items = @("a", "b", "c")

Check "Down, Down, Enter        -> the third" `
    (Run-Menu @([ConsoleKey]::DownArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::Enter) $Items) "c"
Check "Up from the first        -> the last (wrapping)" `
    (Run-Menu @([ConsoleKey]::UpArrow, [ConsoleKey]::Enter) $Items) "c"
Check "Down from the last       -> the first (wrapping)" `
    (Run-Menu @([ConsoleKey]::DownArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::Enter) $Items) "a"
Check "Escape                   -> nothing" `
    (Run-Menu @([ConsoleKey]::Escape) $Items) ""
Check "the key 2                -> the second, no Enter needed" `
    (Run-Menu @([ConsoleKey]::D2) $Items) "b"
Check "the key 9 (off the list) -> ignored" `
    (Run-Menu @([ConsoleKey]::D9, [ConsoleKey]::Enter) $Items) "a"
Check "any other key            -> ignored" `
    (Run-Menu @([ConsoleKey]::A, [ConsoleKey]::Enter) $Items) "a"
Check "empty list               -> nothing, and nothing is asked" `
    (Run-Menu @() @()) ""
Check "a custom label           -> hands back the object, not the label" `
    (Run-Menu @([ConsoleKey]::DownArrow, [ConsoleKey]::Enter) @(1, 2) { param($i) "L-$i" }) "2"
Check "default: Enter takes it without moving" `
    (Run-Menu @([ConsoleKey]::Enter) @("a", "b", "c") $null 2) "c"
Check "default off the list     -> the first" `
    (Run-Menu @([ConsoleKey]::Enter) @("a", "b", "c") $null 9) "a"
Check "negative default         -> the first" `
    (Run-Menu @([ConsoleKey]::Enter) @("a", "b", "c") $null -1) "a"
Check "default = last, Down     -> wraps to the first" `
    (Run-Menu @([ConsoleKey]::DownArrow, [ConsoleKey]::Enter) @("a", "b", "c") $null 2) "a"

Write-Output ""
Write-Output "--- a row is one line, box or no box ---"

# The menu repaints its rows in place, and that only works while every row is
# exactly one line: a row wider than the window wraps, the block is then taller
# than the arithmetic assumes, and the next keypress paints the choice one line
# off - the row it replaced keeps its old marker, so the same row appears twice.
# That is what happened on a real console in the checklist, where a row carries
# four more characters than a plain one (the "[x] " box) and the cut did not
# know it. These checks are the invariant itself: marker, box and label
# together, whatever the label, never exceed the width the console gave.
$Wide = @(("x" * 400 -join ""), ("y" * 400 -join ""))
$Cut = Format-MenuLabels -Labels $Wide -Width 40
Check "a plain row fits the width          " `
    ((@($Cut | ForEach-Object { 4 + $_.Length }) | Measure-Object -Maximum).Maximum) "39"
$Cut = Format-MenuLabels -Labels $Wide -Width 40 -Prefix 8
Check "a row with its box fits it too     " `
    ((@($Cut | ForEach-Object { 8 + $_.Length }) | Measure-Object -Maximum).Maximum) "39"
$Cut = Format-MenuLabels -Labels $Wide -Width 40 -Prefix 0
Check "a title or a hint fits it too       " `
    ((@($Cut | ForEach-Object { $_.Length }) | Measure-Object -Maximum).Maximum) "39"
Check "  ... and the cut shows as one      " ($Cut[0] -like "x*...") "True"
Check "a short label is left alone         " (@(Format-MenuLabels -Labels @("court") -Width 40)[0]) "court"
Check "a host that says no width cuts none " (@(Format-MenuLabels -Labels @("x" * 400 -join "") -Width 0)[0]).Length "400"

Write-Output ""
Write-Output "--- no console (numbered fallback, answers read from standard input) ---"
Check "fallback: answer 2       -> the second" `
    (Select-FromList -Title "T" -Items $Items) "b"
Check "fallback: empty answer   -> nothing" `
    (Select-FromList -Title "T" -Items $Items) ""
Check "fallback multi: 1, 2 then v -> both" `
    ((Select-FromList -Title "T" -Items $Items -Multi) -join ",") "a,b"
Check "fallback multi: v alone     -> an empty list, not a cancellation" `
    ($null -eq (Select-FromList -Title "T" -Items $Items -Multi)) "False"
Check "  ... and that list is really empty" `
    ((Select-FromList -Title "T" -Items $Items -Multi).Count) "0"
Check "fallback multi: empty line  -> cancelled" `
    (Select-FromList -Title "T" -Items $Items -Multi) ""

Write-Output ""
Write-Output "--- the drawing: the top of the block is read back AFTER it is drawn ---"
# A console that scrolls while the block is written: it answers 20 before the
# rows are drawn and 40 after. Read before drawing, 20 puts every row 20 lines
# too high - the bug that showed up as one more copy of the list per arrow. The
# stand-in for Write-MenuRow is what tells the two moments apart.
$script:Drawing = $false
$script:Moves = @()
function Write-MenuRow { param([int]$Index, [int]$Current, [string[]]$Labels) $script:Drawing = $true }
function Get-ConsoleTop { if ($script:Drawing) { return 40 } return 20 }
function Set-ConsoleTop { param([int]$Top) $script:Moves += $Top; return $true }

$script:Queue = New-Object System.Collections.Queue
$script:Queue.Enqueue([ConsoleKey]::DownArrow)
$script:Queue.Enqueue([ConsoleKey]::Enter)
$Reader = { $script:Queue.Dequeue() }
$Picked = Select-FromList -Title "T" -Items @("a", "b", "c", "d", "e") -KeyReader $Reader

Check "top read after (34..38, then 40) -> no drift" ($script:Moves -join ",") "34,35,36,37,38,40"
Check "and the choice is still right" $Picked "b"

Write-Output ""
Write-Output "--- multi-select: space checks, Enter hands the list back ---"
function Run-Multi {
    param([ConsoleKey[]]$Keys, [object[]]$Items, [int[]]$Checked = @(), [scriptblock]$Label)
    $script:Queue = New-Object System.Collections.Queue
    foreach ($Key in $Keys) { $script:Queue.Enqueue($Key) }
    $Reader = { $script:Queue.Dequeue() }
    if ($Label) {
        return Select-FromList -Title "T" -Items $Items -Label $Label -KeyReader $Reader -Multi -CheckedIndexes $Checked
    }
    return Select-FromList -Title "T" -Items $Items -KeyReader $Reader -Multi -CheckedIndexes $Checked
}

$PackItems = @("gcp", "vision", "python")
Check "space checks                 -> the list handed back" `
    ((Run-Multi @([ConsoleKey]::Spacebar, [ConsoleKey]::Enter) $PackItems) -join ",") "gcp"
Check "space twice unchecks" `
    ((Run-Multi @([ConsoleKey]::Spacebar, [ConsoleKey]::Spacebar, [ConsoleKey]::Enter) $PackItems) -join ",") ""
Check "two packs checked, in the list's order" `
    ((Run-Multi @([ConsoleKey]::Spacebar, [ConsoleKey]::DownArrow, [ConsoleKey]::DownArrow, [ConsoleKey]::Spacebar, [ConsoleKey]::Enter) $PackItems) -join ",") "gcp,python"
Check "already checked: move down and uncheck" `
    ((Run-Multi @([ConsoleKey]::DownArrow, [ConsoleKey]::Spacebar, [ConsoleKey]::Enter) $PackItems @(1, 2)) -join ",") "python"
Check "a digit toggles instead of leaving" `
    ((Run-Multi @([ConsoleKey]::D2, [ConsoleKey]::Enter) $PackItems) -join ",") "vision"
# $null -eq is the sharp test here: .Count on $null answers 0 as well, so a
# check written that way would pass whether the list came back or not.
Check "Enter with nothing checked  -> an empty list, not a cancellation" `
    ($null -eq (Run-Multi @([ConsoleKey]::Enter) $PackItems)) "False"
Check "  ... and that list is really empty" `
    ((Run-Multi @([ConsoleKey]::Enter) $PackItems).Count) "0"
Check "Escape                       -> nothing at all" `
    (Run-Multi @([ConsoleKey]::Escape) $PackItems) ""
Check "single-select: space does nothing" `
    ((Run-Menu @([ConsoleKey]::Spacebar, [ConsoleKey]::Enter) $PackItems) -join ",") "gcp"
Check "the box shows in the row" `
    ((Format-MenuRow -Index 1 -Current 0 -Labels $PackItems -Checked @($true, $false, $true)).Trim()) "[ ] vision"

Write-Output ""
Write-Output "--- the window: rows are cut, a tall list scrolls ---"
# An 80-column window and a 6-line one, and the menu must still work: the long
# label is cut rather than wrapping (a wrapped row is a row the arithmetic no
# longer counts), and the list scrolls instead of refusing to draw.
$script:Drawn = @()
function Write-MenuRow {
    param([int]$Index, [int]$Current, [string[]]$Labels)
    if ($Index -eq $Current) { $script:Drawn += ("#" + $Labels[$Index]) }
    else { $script:Drawn += $Labels[$Index] }
}
function Get-ConsoleSize { return @(40, 6) }

$Long = "remove_pack  uninstall optional tooling from an instance, dependencies included"
# @() around each: a one-element list unrolls to its element, and [0] on a
# string is its first LETTER - the trap the scripts themselves carry a comment
# about, met again in the test that checks them.
$Cut = @(Format-MenuLabels -Labels @($Long) -Width 40)[0]
$Short = @(Format-MenuLabels -Labels @("short") -Width 40)[0]
$NoWidth = @(Format-MenuLabels -Labels @($Long) -Width 0)[0]
Check "cut to the width (39 max)" ($Cut.Length -le 39) $true
Check "cut: the end becomes ..." ($Cut.EndsWith("...")) $true
Check "a short label stays whole" $Short "short"
Check "unknown width (0): nothing is cut" $NoWidth $Long

$script:Queue = New-Object System.Collections.Queue
foreach ($n in 1..6) { $script:Queue.Enqueue([ConsoleKey]::DownArrow) }
$script:Queue.Enqueue([ConsoleKey]::Enter)
$Reader = { $script:Queue.Dequeue() }
$script:Drawn = @()
$Picked = Select-FromList -Title "T" -Items @("i0", "i1", "i2", "i3", "i4", "i5", "i6", "i7", "i8", "i9") -KeyReader $Reader

$Last = $script:Drawn[-3..-1] -join "|"
Check "the window followed the choice (i6 current)" $Last "i4|i5|#i6"
Check "and the choice is still right" $Picked "i6"

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures

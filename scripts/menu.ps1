# ==============================================================================
# ASKING: THE LIST EVERY COMMAND SHOWS
# ==============================================================================
# The instances, the packs, the archives: every command in this family offers a
# list, and until now each one printed it by hand and asked for a number.
#
# Select-FromList draws the same list so it can be walked with the arrows: up
# and down move (and wrap), Enter chooses, Escape cancels, and in a list of
# nine or fewer a digit chooses directly.
#
# It falls back to the numbered prompt - the one every command used before -
# and the fallback is the important half, because a menu that waits for a key
# on a machine with no keyboard waits forever:
#
#   - no console (input redirected: a pipe, a script, a test). The check is made
#     BEFORE reading, never with a try/catch around the read: [Console]::ReadKey
#     does not throw there, it BLOCKS - measured on 2026-09-25, with two minutes
#     of nothing to show for it;
#   - a list too tall or too wide for the window, where moving the cursor about
#     stops being honest;
#   - a host without a real console (the ISE), where $Host.UI.RawUI throws.
#
# This file defines functions; it is not a command. instance.ps1 loads it, and
# every command loads instance.ps1.
# ==============================================================================

# Is there a keyboard we can read without hanging? Both checks are cheap and
# neither one blocks: CursorTop and KeyAvailable throw without a console, and
# a throw is an answer.
function Test-KeyInput {
    if ([Console]::IsInputRedirected) { return $false }
    try {
        $null = $Host.UI.RawUI.KeyAvailable
        return $true
    } catch {
        return $false
    }
}

# The one line in the project that touches the keyboard. [ConsoleKey] is what
# the loop below compares: UpArrow, DownArrow, Enter, Escape, D1..D9.
function Read-MenuKey {
    return [Console]::ReadKey($true).Key
}

# The cursor, asked gently, and answered honestly: $null means the host would
# not say, which is not the same as "row zero". A terminal that refuses to be
# drawn on - a redrawn window, a capture, a test - leaves the menu working, only
# uglier: the choice is the keys, never the paint.
function Get-ConsoleTop {
    try { return [Console]::CursorTop } catch { return $null }
}

# Moves the cursor, and says whether it moved. A silent failure here is what
# turned a menu into a stack of copies once: every repaint that could not be
# placed was written where the cursor already was, so each arrow added a block.
function Set-ConsoleTop {
    param([int]$Top)
    try {
        [Console]::SetCursorPosition(0, $Top)
        return ([Console]::CursorTop -eq $Top)
    } catch {
        return $false
    }
}

# One row of the list, as it is drawn: the marker and the colours say where the
# choice is, so a terminal that renders neither still reads correctly.
function Format-MenuRow {
    param([int]$Index, [int]$Current, [string[]]$Labels)
    if ($Index -eq $Current) { return ("  > " + $Labels[$Index]) }
    return ("    " + $Labels[$Index])
}

function Write-MenuRow {
    param([int]$Index, [int]$Current, [string[]]$Labels)
    $Row = Format-MenuRow -Index $Index -Current $Current -Labels $Labels
    if ($Index -eq $Current) {
        Write-Host $Row -ForegroundColor Cyan
    } else {
        Write-Host $Row
    }
}

# Width and height, or zeroes when the host will not say - zero meaning "no
# constraint", so a host that keeps quiet is never a reason to give up on the
# arrows. ($null, unlike 0, means the host said nothing at all.)
function Get-ConsoleSize {
    try {
        $Size = $Host.UI.RawUI.WindowSize
        return @([int]$Size.Width, [int]$Size.Height)
    } catch {
        return @(0, 0)
    }
}

# The prompt every command used before the arrows: numbered rows, a number
# typed, an empty answer cancelling. Read-Host returns an empty string when its
# input is closed, so a run with no console can never loop forever.
function Select-ByNumber {
    param([string]$Title, [string[]]$Labels, [object[]]$Items)

    Write-Host ""
    if ($Title) { Write-Host "$Title" -ForegroundColor Cyan }
    for ($Index = 0; $Index -lt $Items.Count; $Index++) {
        Write-Host ("  {0,2}.  {1}" -f ($Index + 1), $Labels[$Index])
    }
    Write-Host "   0.  Cancel"

    while ($true) {
        $Answer = [string](Read-Host "Which one? (0 to cancel)")
        if ([string]::IsNullOrWhiteSpace($Answer)) { return $null }
        $Number = 0
        if ([int]::TryParse($Answer.Trim(), [ref]$Number)) {
            if ($Number -eq 0) { return $null }
            if ($Number -ge 1 -and $Number -le $Items.Count) { return $Items[$Number - 1] }
        }
        Write-Host "  '$Answer' is not one of the numbers above." -ForegroundColor Yellow
    }
}

# The arrow menu. The rows are drawn once and repainted in place: the cursor
# goes back up to the first row and each line is written again. Every label
# keeps its length, so nothing has to be erased - and no Clear-Host, which
# would wipe what the user scrolled through before.
#
# -KeyReader exists for the tests: it replaces the keyboard with a script that
# returns a [ConsoleKey] on demand, so the whole loop - wrapping included - runs
# with no terminal in sight.
function Select-WithArrows {
    param([string]$Title, [string[]]$Labels, [object[]]$Items, [scriptblock]$KeyReader)

    $Count = $Items.Count
    $Current = 0

    # Drawn once, in the natural course of the output - and the top row is READ
    # BACK from the cursor only after that. Not computed before drawing: writing
    # the block can scroll the console (a command that prints a lot before its
    # menu leaves the cursor near the bottom), the lines just written move up
    # with the scroll, and a row number remembered from before it is wrong by
    # exactly what scrolled. That was the bug: every arrow added one more copy
    # of the list, lower each time, whenever the console had scrolled.
    Write-Host ""
    if ($Title) { Write-Host "$Title" -ForegroundColor Cyan }
    for ($Index = 0; $Index -lt $Count; $Index++) {
        Write-MenuRow -Index $Index -Current $Current -Labels $Labels
    }
    Write-Host "  up/down to move, Enter to choose, Escape to cancel" -ForegroundColor DarkGray

    $Cursor = Get-ConsoleTop
    $Top = if ($null -ne $Cursor) { $Cursor - ($Count + 1) } else { 0 }
    # No cursor reading (a test, a host that will not say): the loop still
    # answers the keys, it simply does not repaint - there is nothing to paint
    # on. Same for a top row above the screen, which no arithmetic can fix.
    $CanPaint = ($null -ne $Cursor) -and ($Top -ge 0)

    while ($true) {
        $Key = if ($KeyReader) { & $KeyReader } else { Read-MenuKey }
        $Last = $Count - 1
        $Moved = $true

        if ($Key -eq [ConsoleKey]::UpArrow) {
            $Current = if ($Current -eq 0) { $Last } else { $Current - 1 }
        } elseif ($Key -eq [ConsoleKey]::DownArrow) {
            $Current = if ($Current -eq $Last) { 0 } else { $Current + 1 }
        } elseif ($Key -eq [ConsoleKey]::Enter) {
            if ($CanPaint) { $null = Set-ConsoleTop ($Top + $Count + 1) }
            return $Items[$Current]
        } elseif ($Key -eq [ConsoleKey]::Escape) {
            if ($CanPaint) { $null = Set-ConsoleTop ($Top + $Count + 1) }
            return $null
        } elseif ($Key -ge [ConsoleKey]::D1 -and $Key -le [ConsoleKey]::D9) {
            $Wanted = [int]$Key - [int][ConsoleKey]::D1
            if ($Wanted -lt $Count) {
                if ($CanPaint) { $null = Set-ConsoleTop ($Top + $Count + 1) }
                return $Items[$Wanted]
            }
        } elseif ($Key -ge [ConsoleKey]::NumPad1 -and $Key -le [ConsoleKey]::NumPad9) {
            $Wanted = [int]$Key - [int][ConsoleKey]::NumPad1
            if ($Wanted -lt $Count) {
                if ($CanPaint) { $null = Set-ConsoleTop ($Top + $Count + 1) }
                return $Items[$Wanted]
            }
        } else {
            $Moved = $false                   # a key the menu has no use for
        }

        if (-not $Moved -or -not $CanPaint) { continue }

        # Repaint the rows where they already are. If the cursor will not go
        # back, the whole block is written again instead: one more copy is
        # ugly, a screen showing a choice that is no longer the current one is
        # worse - and this is the one failure that must never pass unnoticed.
        $Placed = $true
        for ($Index = 0; $Index -lt $Count; $Index++) {
            if (-not (Set-ConsoleTop ($Top + $Index))) { $Placed = $false; break }
            Write-MenuRow -Index $Index -Current $Current -Labels $Labels
        }
        if (-not $Placed) {
            for ($Index = 0; $Index -lt $Count; $Index++) {
                Write-MenuRow -Index $Index -Current $Current -Labels $Labels
            }
        }
    }
}

# What every caller wants: the list, the arrows when the machine can have them,
# the numbered prompt otherwise, and the chosen item - or $null, which every
# caller reads as "the user cancelled".
function Select-FromList {
    param(
        [string]$Title = "",
        [object[]]$Items = @(),
        [scriptblock]$Label = { param($Item) [string]$Item },
        [scriptblock]$KeyReader
    )

    $Items = @($Items)
    if ($Items.Count -eq 0) { return $null }
    $Labels = @($Items | ForEach-Object { [string](& $Label $_) })

    # A -KeyReader means a test asked for the arrows: it stands in for the
    # console, which a test has not got.
    $Arrows = [bool]$KeyReader -or (Test-KeyInput)

    if ($Arrows) {
        $Size = Get-ConsoleSize
        $Width = $Size[0]
        $Height = $Size[1]
        $Widest = ($Labels | Measure-Object -Property Length -Maximum).Maximum + 6
        if (($Width -gt 0 -and $Widest -gt $Width) -or
            ($Height -gt 0 -and ($Items.Count + 3) -gt $Height)) {
            $Arrows = $false
        }
    }

    if (-not $Arrows) {
        return (Select-ByNumber -Title $Title -Labels $Labels -Items $Items)
    }
    return (Select-WithArrows -Title $Title -Labels $Labels -Items $Items -KeyReader $KeyReader)
}

# ---------------------------------------------------------------------------
# THE LIST THIS FAMILY SHOWS MOST
# ---------------------------------------------------------------------------
# The instances that are OURS, with the state and the room each takes. The list
# is filtered on the marker: the machine holds other distributions - Docker
# Desktop's, a colleague's - and none of them are ours to touch. An instance
# that is not in this list is not missing; it is not ours.
function Select-Distro {
    $All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.BasePath } | Sort-Object Name)
    if ($All.Count -eq 0) {
        Write-Host ""
        Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor Red
        Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor Yellow
        Write-Host "        Already have one? Make it ours with  .\wsl.ps1 adopt" -ForegroundColor Yellow
        exit 1
    }

    $Running = Get-DistroNames -Running
    $Chosen = Select-FromList -Title "Our Instances" -Items $All -Label {
        param($Instance)
        $State = if ($Running -contains $Instance.Name) { "running" } else { "stopped" }
        "{0,-30} {1,-8} {2,10}" -f $Instance.Name, $State, (Format-Size (Get-VhdxSize $Instance.BasePath))
    }

    if (-not $Chosen) {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor Green
        exit 0
    }
    return $Chosen
}

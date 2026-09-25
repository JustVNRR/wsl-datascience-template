[CmdletBinding()]
param ()

# No parameter, and no question either: this command only reads. Nothing here
# can modify anything, so it can be run at any moment, and its exit code says
# whether there was anything to show (1 when there is none, like the lists of
# the other commands).

$ErrorActionPreference = "Stop"

# One working folder, no guessing: an instance lives in <Root>\<name>, and
# every archive in <Root>\archives - the rule the other scripts follow too.
$Root = if (Test-Path "D:\") { "D:\WSL" } else { "$env:USERPROFILE\WSL" }

# What the whole family shares: how to tell one of our instances from any other
# registered one.
$InstanceLib = Join-Path $PSScriptRoot "instance.ps1"
if (-not (Test-Path $InstanceLib)) {
    Write-Host ""
    Write-Host "[ABORT] scripts\instance.ps1 is missing - the scripts\ folder is incomplete." -ForegroundColor Red
    exit 1
}
. $InstanceLib

# 1. Our instances, running or stopped: the sum of what start and stop offer,
# and nothing else. Sorted by name, like every list in this family.
$All = @(Get-Distros | Where-Object { Test-TemplateInstance -Folder $_.BasePath } | Sort-Object Name)
if ($All.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor Red
    Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor Yellow
    Write-Host "        Already have one? Make it ours with  .\wsl.ps1 adopt" -ForegroundColor Yellow
    exit 1
}

$Running = Get-DistroNames -Running

Write-Host ""
Write-Host "Instances of this template:" -ForegroundColor Cyan
for ($Index = 0; $Index -lt $All.Count; $Index++) {
    $Entry = $All[$Index]
    $State = if ($Running -contains $Entry.Name) { "running" } else { "stopped" }
    Write-Host ("  {0,2}.  {1,-30} {2,-8} {3,10}  {4}" -f ($Index + 1), $Entry.Name, $State,
        (Format-Size (Get-VhdxSize $Entry.BasePath)), $Entry.BasePath)
}

# 2. The archives. Nothing to tell apart here: everything in that folder was
# written by archive.ps1, and it shows what it holds - whatever it is.
$ArchiveFolder = Join-Path $Root "archives"
$Archives = @()
if (Test-Path $ArchiveFolder) {
    $Archives = @(Get-ChildItem -Path $ArchiveFolder -Directory |
        Where-Object { (Get-ChildItem -Path $_.FullName -Filter "*.tar*" -File).Count -gt 0 } |
        Sort-Object LastWriteTime -Descending)
}

if ($Archives.Count -gt 0) {
    Write-Host ""
    Write-Host "Archives in ${ArchiveFolder} (most recent first):" -ForegroundColor Cyan
    foreach ($Entry in $Archives) {
        $Tar = Get-ChildItem -Path $Entry.FullName -Filter "*.tar*" -File |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host ("      {0,-30} {1,10}  {2}" -f $Entry.Name, (Format-Size $Tar.Length),
            $Entry.LastWriteTime.ToString("yyyy-MM-dd HH:mm"))
    }
}

# 3. Marked folders that no instance claims: what an interrupted removal leaves
# behind, or a distribution unregistered from outside this repository. Nothing
# else shows them - this is the one place they are not invisible.
$RegisteredPaths = @($All | ForEach-Object { $_.BasePath })
$Forgotten = @()
if (Test-Path $Root) {
    foreach ($Folder in (Get-ChildItem -Path $Root -Directory -ErrorAction SilentlyContinue)) {
        if ((Test-TemplateInstance -Folder $Folder.FullName) -and ($RegisteredPaths -notcontains $Folder.FullName)) {
            $Forgotten += $Folder
        }
    }
}

if ($Forgotten.Count -gt 0) {
    Write-Host ""
    Write-Host "Folders left behind by an instance that is gone:" -ForegroundColor Yellow
    foreach ($Folder in $Forgotten) {
        Write-Host ("      {0,-30} {1,10}  {2}" -f $Folder.Name,
            (Format-Size (Get-VhdxSize $Folder.FullName)), $Folder.FullName) -ForegroundColor Yellow
    }
    Write-Host "      No instance claims them, and no command removes them: delete them by hand." -ForegroundColor DarkGray
}

Write-Host ""

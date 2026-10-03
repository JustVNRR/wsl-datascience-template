# Reads every .ps1 in the checkout with the parser PowerShell itself uses
# before it runs a file. Run once per engine - 5.1 and 7 - and a parse error
# left here surfaces the day a command runs.
#
# Usage:  pwsh -NoProfile -File tests\parse-check.ps1

$files = Get-ChildItem -Recurse -Filter *.ps1
$bad = 0
foreach ($f in $files) {
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errors)
    if ($errors.Count -gt 0) {
        Write-Host "::error file=$($f.FullName)::$($errors.Count) parse error(s)"
        foreach ($e in $errors) { Write-Host ("  line {0}: {1}" -f $e.Extent.StartLineNumber, $e.Message) }
        $bad = 1
    }
}
Write-Host "$($files.Count) .ps1 file(s) read, $bad failure(s)."
exit $bad

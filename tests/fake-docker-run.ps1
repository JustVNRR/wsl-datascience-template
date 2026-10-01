# Runs a command of the template with the stand-in docker (fake-docker\) ahead
# on the PATH, so everything before a deployment can be exercised with no Docker
# Desktop and no instance. The answers come on standard input, the way the
# numbered menus read them when there is no console.
#
# The paths come from this file's own folder: the repository may sit anywhere.
$env:PATH = (Join-Path $PSScriptRoot "fake-docker") + ";" + $env:PATH

& (Join-Path $PSScriptRoot "..\wsl.ps1") @args

if ($null -eq $LASTEXITCODE) { exit 0 }
exit $LASTEXITCODE

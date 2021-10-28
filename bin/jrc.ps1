$JRC_DIRECTORY=$PSScriptRoot
$CURRENT_DIRECTORY=(Get-Item -Path '.\' -Verbose).FullName
$JRC_PARAMETERS=$args
jai $JRC_DIRECTORY\..\jrc.jai -- "$CURRENT_DIRECTORY" $JRC_PARAMETERS
if (Test-Path ".build") { Remove-Item ".build" -Recurse -Force }

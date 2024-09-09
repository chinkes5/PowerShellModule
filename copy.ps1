$projectRoot = $env:projectRoot

Write-Host "##[info] Reading config file..."
$config = Get-Content (Join-Path $projectRoot -ChildPath 'module-config.json') | ConvertFrom-Json
Write-Output "Project root: $projectRoot"
$hasPrivateFunctions = $env:hasPrivateFunctions
$hasPesterTests = $env:hasPesterTests
Write-Host "##[info] Got these- private = '$hasPrivateFunctions', and tests = '$hasPesterTests'"

$manifestPath = Join-Path -Path $projectRoot -ChildPath "$($config.name).psd1"
Write-Output "Manifest Path: $manifestPath"

if (Test-Path $manifestPath) {
    Write-Output "found Manifest file updated on: $((Get-Item $manifestPath).LastWriteTimeUtc)"

    Write-Host "##[info] Copy new module to build staging directory, '$($env:Build_StagingDirectory)'..."
    $destination = Join-Path $env:Build_StagingDirectory -ChildPath "$($config.name)"
    if (-not (Test-Path $destination)) {
        New-Item $destination -ItemType Directory
    }

    Copy-Item (Join-Path $projectRoot -ChildPath "$($config.name).psm1") -Destination $destination -Verbose
    Copy-Item (Join-Path $projectRoot -ChildPath "$($config.name).psd1") -Destination $destination -Verbose
    Copy-Item (Join-Path $projectRoot -ChildPath "$($config.name).nuspec") -Destination $destination -Verbose
    Copy-Item (Join-Path $projectRoot -ChildPath 'Public') -Destination $destination -Filter '*.ps1' -Recurse -Verbose
    Copy-Item (Join-Path $projectRoot -ChildPath 'en-US') -Destination $destination -Filter '*.ps1' -Recurse -Verbose
    if ($hasPrivateFunctions) {
        Copy-Item (Join-Path $projectRoot -ChildPath 'Private') -Destination $destination -Filter '*.ps1' -Recurse -Verbose
    }
    if ($hasPesterTests) {
        Copy-Item (Join-Path $projectRoot -ChildPath 'Tests') -Destination $destination -Recurse -Verbose
    }
}
else {
    Write-Error "Can't find Manifest file!"
}

$projectRoot = $env:projectRoot

Write-Host "##[info] Reading config file..."
$config = Get-Content (Join-Path $projectRoot -ChildPath 'module-config.json') | ConvertFrom-Json
Write-Output "Project root: $projectRoot"
$hasPrivateFunctions = $env:hasPrivateFunctions
$hasPesterTests = $env:hasPesterTests
Write-Host "##[info] Got these- private = '$hasPrivateFunctions', and tests = '$hasPesterTests'"

$manifestPath = Join-Path -Path $projectRoot -ChildPath "$($config.name).psd1"
Write-Output "Manifest Path: $manifestPath"
$testList = Join-Path (Join-Path $projectRoot -ChildPath "Tests") -ChildPath "Module-tests"
Write-Output "Tests Path: $testList"
$testResultFile = Join-Path $projectRoot -ChildPath (Join-Path "Tests" -ChildPath "Tests.XML")
Write-Output "Results Path: $testResultFile"

Invoke-Pester -Script $testList -OutputFile $testResultFile -OutputFormat NUnitXml

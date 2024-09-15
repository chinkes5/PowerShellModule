$projectRoot = $env:projectRoot

Write-Host "##[info] Reading config file..."
$config = Get-Content (Join-Path $projectRoot -ChildPath 'module-config.json') | ConvertFrom-Json
Write-Output "Project root: $projectRoot"
$hasPrivateFunctions = $env:hasPrivateFunctions
$hasPesterTests = $env:hasPesterTests
Write-Host "##[info] Got these- private = '$hasPrivateFunctions', and tests = '$hasPesterTests'"

# Running my tests off the copy in the staging directory
$modulePath = Join-Path -Path $env:Build_StagingDirectory -ChildPath "$($config.name)"
$manifestPath = Join-Path -Path $modulePath -ChildPath "$($config.name).psd1"
Write-Output "Manifest Path: $manifestPath"
$testList = Join-Path $modulePath -ChildPath "Tests"
Write-Output "Tests Path: $testList"
$testResultFile = Join-Path $modulePath -ChildPath (Join-Path "Tests" -ChildPath "Tests.XML")
Write-Output "Results Path: $testResultFile"

Import-Module PSScriptAnalyzer -Verbose
Import-Module Pester -Verbose
Invoke-Pester -Script $testList -OutputFile $testResultFile -OutputFormat NUnitXml

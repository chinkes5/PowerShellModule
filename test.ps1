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
if (Test-Path $manifestPath) {
Write-Output "Manifest Path: $manifestPath"
$testList = Join-Path $modulePath -ChildPath "Tests"
Write-Output "Tests Path: $testList"

Import-Module PSScriptAnalyzer -Verbose
Import-Module Pester -Verbose
    Import-Module $manifestPath -Force -Verbose
    Get-Module $manifestPath -ListAvailable
    $config = New-PesterConfiguration
    $config.Run.Path = $testList
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.outputPath = $manifestPath
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = Join-Path $testList -ChildPath "Tests.XML"
    $config.TestResult.OutputFormat = "NUnit3"
    Invoke-Pester -Configuration $config
}
else {
    Write-Host "##[warning] Manifest Path: $manifestPath does not exist"
    Resolve-Path "$($env:Build_StagingDirectory)\**\*.psd1" -Verbose
}

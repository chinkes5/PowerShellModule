Write-Host "##[info] Install platyps..."
Install-Module -Name platyPS -Force

Write-Host "##[info] Get module config..."
$projectRoot = $env:projectRoot
$config = Get-Content (Join-Path $projectRoot -ChildPath 'module-config.json') | ConvertFrom-Json
Write-Output "Project root: $projectRoot"
$hasPrivateFunctions = $env:hasPrivateFunctions
$hasPesterTests = $env:hasPesterTests
Write-Host "##[info] Got these- private = '$hasPrivateFunctions', and tests = '$hasPesterTests'"

# will need to load the module as this calls the function and not the file...
Write-Host "##[info] Import the module..."
$moduleRoot = Join-Path $env:Build_StagingDirectory -ChildPath $config.name
Import-Module -Name (Join-Path -Path $moduleRoot -ChildPath "$($config.name).psd1") -Verbose

Write-Host "##[info] Export markdown from context help in each function..."
$functions = Get-ChildItem -Path (Join-Path -Path $moduleRoot -ChildPath "Public") -Filter *.ps1
$mdFilePath = (Join-Path -Path $PSScriptRoot -ChildPath "docs")
foreach ($function in $functions) {
    Write-Host "##[info] Exporting markdown for $($function.BaseName)..."
    $functionName = ($function.BaseName).Replace("Get-", "")
    $outputFile = Join-Path -Path $mdFilePath -ChildPath "$($functionName).md"
    $markdownParams = @{
        Command               = $function.BaseName
        OutputFolder          = $outputFile
        AlphabeticParamsOrder = $true
        Verbose               = $true
    }
    New-MarkdownHelp @markdownParams
}

Write-Host "##[info] Convert markdown to to MAML..."
# $mamlFile = Join-Path -Path (Join-Path -Path $moduleRoot -ChildPath "en-US") -ChildPath "$($config.name).help.xml"
$mamlFile = Join-Path -Path $moduleRoot -ChildPath "en-US"
# New-ExternalHelp -Path (Join-Path $mdFilePath -ChildPath "*.md") -OutputPath $mamlFile -Verbose
New-ExternalHelp -Path $mdFilePath -OutputPath $mamlFile -Verbose

Write-Output "Updating nuspec file with new help files..."
$settings = [xml](Get-Content "$projectRoot/$($config.name).nuspec")
$settings.package.metadata.files.file | ? {$_.src -eq 'en-US'} | % {$settings.package.metadata.files.RemoveChild($_)}
$settings.package.metadata.files.AppendChild($settings.CreateElement('file')) | % {$_.SetAttribute('src', 'en-US/**'); $_.SetAttribute('target', 'en-US/.')}
$settings.Save("$projectRoot\$($config.name).nuspec")
Write-Output "Built MAML help files!"
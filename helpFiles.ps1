Write-Host "##[info] Install platyps..."
Install-Module -Name platyPS -Force

Write-Host "##[info] Get module config..."
$projectRoot = $env:projectRoot
$config = Get-Content (Join-Path $projectRoot -ChildPath 'module-config.json') | ConvertFrom-Json

Write-Host "##[info] Export markdown from context help in each function..."
# switching over to the staging directory where the tests occurred, we will package from
# here too, might as well build the help file in this location.
$moduleRoot = Join-Path $env:Build_StagingDirectory -ChildPath $config.name

# will need to load the module as this calls the function and not the file...
$functions = Get-ChildItem -Path (Join-Path -Path $moduleRoot -ChildPath "Public") -Filter *.ps1
Import-Module -Name $moduleRoot -Force -Verbose
foreach ($function in $functions) {
    Write-Host "##[info] Exporting markdown for $($function.BaseName)..."
    $functionName = ($function.BaseName).Replace("Get-", "")
    $outputFile = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "docs") -ChildPath "$($functionName).md"
    $markdownParams = @{
        Command               = $functionName
        OutputFolder          = $outputFile
        AlphabeticParamsOrder = $true
        # WithModulePage        = $true
        # HelpVersion           = $env:BUILDVER
        # Encoding              = [System.Text.Encoding]::UTF8
        Verbose               = $true
    }
    New-MarkdownHelp @markdownParams
}

Write-Host "##[info] Convert markdown to to MAML..."
$mamlFile = Join-Path -Path (Join-Path -Path $moduleRoot -ChildPath "en-US") -ChildPath "$($config.name).help.xml"
New-ExternalHelp -Path (Join-Path -Path $moduleRoot -ChildPath "docs") -OutputFile $mamlFile -Verbose

Write-Output "Built MAML help files!"
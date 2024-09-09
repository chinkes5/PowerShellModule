#region Initialize
$buildVersion = $env:BUILDVER
$projectRoot = Resolve-Path "$PSScriptRoot"
Write-Host "##vso[task.setvariable variable=projectRoot]$projectRoot"

Write-Host "##[info] Reading config file..."
$config = Get-Content (Join-Path $projectRoot -ChildPath 'module-config.json') | ConvertFrom-Json
$publicFuncFolderPath = Join-Path -Path $projectRoot -ChildPath 'Public'
if (-not (Test-Path $publicFuncFolderPath -PathType Container)) {
    throw "Can't find Public folder in $projectRoot"
}
Write-Host "##[info] Checking for private functions..."
if (Test-Path (Join-Path $projectRoot -ChildPath 'Private') -PathType Container) {
    $hasPrivateFunctions = $true
    Write-Output "Found Private folder in $projectRoot, saving pipeline variable..."
    Write-Host "##vso[task.setvariable variable=hasPrivateFunctions]$hasPrivateFunctions"
}
Write-Host "##[info] Checking for Pester tests..."
if (Test-Path (Join-Path $projectRoot -ChildPath 'Tests') -PathType Container) {
    $hasPesterTests = $true
    Write-Output "Found Pester tests in $projectRoot, saving pipeline variable..."
    Write-Host "##vso[task.setvariable variable=hasPesterTests]$hasPesterTests"
}
#endregion

#region Manifest
Write-Host "##[info] Building manifest..."
$manifestPath = Join-Path $projectRoot -ChildPath "$($config.name).psd1"
$copyrightDate = if ($config.CopyrightStartYear -eq (Get-Date).Year) { (Get-Date).Year } else { "$($config.CopyrightStartYear)-$((Get-Date).Year)" }
$newManifest = @{
    Path              = $manifestPath
    Guid              = $config.GUID
    Author            = $config.Author
    Description       = $config.Description
    RootModule        = "$($config.name).psm1"
    CompanyName       = $config.CompanyName
    Copyright         = "(c) $copyrightDate $($config.CompanyName). All rights reserved."
    PowerShellVersion = $config.PowerShellVersion
    CmdletsToExport   = @()
    AliasesToExport = @()
    Verbose           = $True
}
New-ModuleManifest @newManifest

Write-Host "##[info] Find all of the public functions..."
if ((Test-Path -Path $publicFuncFolderPath) -and ($publicFunctionNames = Get-ChildItem -Path $publicFuncFolderPath -Filter '*.ps1' | Select-Object -ExpandProperty BaseName)) {
    Write-Output "Found $($publicFunctionNames.Count) public functions"
    $funcStrings = "'$($publicFunctionNames -join "','")'"
}
else {
    Write-Warning "No public functions found at $publicFuncFolderPath!"
    $funcStrings = $null
}
Write-Host "##[info] Add all public functions to FunctionsToExport attribute and update build version..."
if (Test-Path $manifestPath -PathType Leaf) {
    $manifestContent = Get-Content -Path $manifestPath -Raw
    $manifestContent = $manifestContent -replace "ModuleVersion =.*", "ModuleVersion = '$buildVersion'" -replace "FunctionsToExport =.*", "FunctionsToExport = $funcStrings"
    Write-Output "Saving updated manifest '$manifestPath'..."
    $manifestContent | Set-Content -Path $manifestPath
}
else {
    throw "Can't find module manifest: $manifestPath"
}

if (Test-Path $manifestPath) {
    Write-Output "found Manifest file: $((Get-Item $manifestPath).LastWriteTimeUtc)"
}
else {
    Write-Error "Can't find Manifest file!"
}
#endregion

#region NuSpec
Write-Host "##[info] Building NuSpec file..."
$settings = [xml]@"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
    <metadata>
        <id>$($config.name)</id>
        <version>`$VERSIONHERE`$</version>
        <authors>$($config.Author)</authors>
        <description>$($config.Description)</description>
    </metadata>
    <files>
        <file src=".\$($config.name).psm1" target="\" />
        <file src=".\$($config.name).psd1" target="\" />
        <file src=".\Public\**" target="Public\." />
    </files>
</package>
"@

if ($hasPrivateFunctions) {
    Write-Host "##[info] Adding private folder to nuspec..."
    $newFile = $settings.CreateElement("file")
    $newFile.SetAttribute("src", ".\Private\**")
    $newFile.SetAttribute("target", "Private\.")
    $settings.package.files.AppendChild($newFile)
}

if ($hasPesterTests) {
    Write-Host "##[info] Adding Pester tests to nuspec..."
    $newFile = $settings.CreateElement("file")
    $newFile.SetAttribute("src", ".\Tests\**")
    $newFile.SetAttribute("target", "Tests\.")
    $settings.package.files.AppendChild($newFile)
}

$settings.Save("$projectRoot\$($config.name).nuspec")
#endregion

#region Build PSM1
Write-Host "##[info] Building PSM1 file..."
$psm1Content = @"
Set-StrictMode -Version Latest

# Get public and private function definition files.
`$Public = @(Get-ChildItem -Path `$PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
`$Private = @(Get-ChildItem -Path `$PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files.
foreach (`$import in @(`$Public + `$Private)) {
    try {
        if (`$null -ne `$import) {
            Write-Output "Importing `$(`$import.FullName)"
            . "`$(`$import.FullName)" -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-Error "Failed to import function `$(`$import.FullName): `$_"
    }
}

## Export all of the public functions making them available to the user
foreach (`$file in `$Public) {
    Export-ModuleMember -Function `$file.BaseName
}
"@

Set-Content -Path "$projectRoot\$($config.name).psm1" -Value $psm1Content
#endregion

function Remove-OlderModuleVersion {
    try {
        $moduleName = 'My_PS_Module'
        Write-Verbose "Removing older versions of $moduleName..."
        $lastVersion = (Get-Module -ListAvailable -Name $moduleName).Version[0]
        Get-InstalledModule -Name $moduleName -AllVersions | Where-Object -Property Version -LT -Value $lastVersion | Uninstall-Module -Verbose -Force
    }
    catch {
        Write-Error "Can't remove older versions of $moduleName!"
    }
}

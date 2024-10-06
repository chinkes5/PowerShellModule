function New-TFSvariableGroup {
    <#
.SYNOPSIS
Creates a new Pipeline Library from the inputted json file, or if using alias 'Update-', updates existing values.
.DESCRIPTION
The `New-TFSvariableGroup` function creates a new Pipeline Library from the inputted json file. It will overwrite any matching library and values. It uses the TFS REST API to send a POST request to the TFS server.
.PARAMETER apiVersion
Version of Azure DevOps REST API
.PARAMETER Credential
The credentials for the TFS server. This parameter is mandatory unless PATS parameter is used.
.PARAMETER PATS
A PATS token to use to authenticate the request when sent to TFS server. This parameter is mandatory unless Credential parameter is used.
.PARAMETER tfsURL
URL to the TFS project, no protocol, includes collection.
.PARAMETER variableJSON
The description to add to the TFS work item. Needs to adhere to the standard as written in https://learn.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/add?view=azure-devops-server-rest-5.0&tabs=HTTP.
.EXAMPLE
New-TFSvariableGroup -Credential $credential -variableJSON "C:\Temp\vars.json"
.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/
 https://learn.microsoft.com/en-us/rest/api/azure/devops/distributedtask/variablegroups/add?
#>
    [CmdletBinding()]
    [Alias("Update-TFSvariableGroup")]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'Version of Azure DevOps REST API')][string] $apiVersion,
        [Parameter(Mandatory = $true, ParameterSetName = 'cred')][ValidateNotNullOrEmpty()][PSCredential]$Credential,
        [Parameter(Mandatory = $true, ParameterSetName = 'pats')][ValidateNotNullOrEmpty()][string]$PATS,
        [Parameter(HelpMessage = 'URL to the TFS project, no protocol, includes collection.', Mandatory = $true)][string] $tfsURL,
        [Parameter(Mandatory = $true, HelpMessage = 'The json file to input new variables')][System.IO.FileInfo]$variableJSON
    )

    if ($env:My_Module_Config) {
        Write-Verbose "Found config ENV:, reading..."
        $configObject = $env:My_Module_Config | ConvertFrom-Json
    }
    else {
        Write-Verbose "Can't find config ENV:, getting config..."
        $configObject = Get-My_Module_Config -Verbose:($PSBoundParameters['Verbose'] -eq $true)
    }
    $TfsServerUrl = "https://$tfsURL"

    if (($null -eq $Credential) -and ($null -ne $PATS)) {
        $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($PATS)"))
        $Header = @{authorization = "Basic $token" }
    }

    if (!(Test-Path $variableJSON.FullName -PathType Leaf)) {
        throw [System.IO.FileNotFoundException] "Can't find input file!"
    }

    try {
        Write-Verbose "Checking if the library exists already..."
        $TFSBaseURL = "$($TfsServerUrl)/_apis/distributedtask/variablegroups?api-version=$apiVersion"
        $webParams = @{
            Uri         = $TFSBaseURL
            Method      = "Get"
            ContentType = "application/json"
        }
        if ([string]::IsNullOrEmpty($PATS)) {
            $webParams.Add("Credential", $Credential)
        }
        else {
            $webParams.Add("Header", $Header)
        }
        $TFSBaseURLContents = Invoke-RestMethod @webParams
    }
    catch {
        Throw "There was an error finding the variable group listing: `n$($_.Exception.Message)`nAt Line: $($_.InvocationInfo.ScriptLineNumber)"
    }

    try {
        $body = Get-Content -Path $variableJSON | ConvertFrom-Json <# double conversion here, needed? #>
        # TODO: convert and test contents match needed values? Make sure passwords are marked as secret?
    }
    catch {
        throw "Can't read json file: `n$($_.Exception.Message)"
    }

    if ($TFSBaseURLContents.value.Name.Contains($body.name)) {
        Write-Verbose "Found a match, we'll update library $($body.name)..."
        $groupId = ($TFSBaseURLContents.value.Where({ $_.Name -eq $body.name })).id
        $TFSBaseURL = "$($TfsServerUrl)/_apis/distributedtask/variablegroups/$groupId`?api-version=$apiVersion"
        $Method = "Put"
    }
    else {
        Write-Verbose "No matching library name, we'll make new library called $($body.name)..."
        $TFSBaseURL = "$($TfsServerUrl)/_apis/distributedtask/variablegroups?api-version=$apiVersion"
        $Method = "Post"
    }

    try {
        Write-Verbose "Updating or adding library values..."
        $webParams = @{
            Uri         = $TFSBaseURL
            Method      = $Method
            Body        = "$($body | ConvertTo-Json)" <# double conversion here, needed? #>
            ContentType = "application/json"
        }
        if ([string]::IsNullOrEmpty($PATS)) {
            $webParams.Add("Credential", $Credential)
        }
        else {
            $webParams.Add("Header", $Header)
        }
        $TFSBaseURLContents = Invoke-RestMethod @webParams

        return $TFSBaseURLContents
    }
    catch {
        Throw "There was an error updating or creating the variable group: `n$($_.Exception.Message)`nAt Line: $($_.InvocationInfo.ScriptLineNumber)"
    }
}
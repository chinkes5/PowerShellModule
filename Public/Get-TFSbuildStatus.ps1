function Get-TFSbuildStatus {
    <#
.SYNOPSIS
Triggers a build without any parameters based on the build ID supplied
.DESCRIPTION
doesn't allow for any parameters to be set on build!
.PARAMETER BuildID
The build ID to check the status of. This parameter is mandatory.
.PARAMETER Credential
The credentials for accessing the TFS server. This parameter should be of type `PSCredential`.
.PARAMETER PATS
A PATS token to use to authenticate the request when sent to TFS server
.PARAMETER tfsURL
URL to the TFS project, no protocol, includes collection.
.PARAMETER apiVersion
Version of Azure DevOps REST API
.EXAMPLE
New-TFSbuildQueue -BuildID 166 -Credential $credential
.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/build/status/get?view=azure-devops-server-rest-5.0
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$BuildID,
        [Parameter(Mandatory = $true, ParameterSetName = 'cred')][ValidateNotNullOrEmpty()][PSCredential]$Credential,
        [Parameter(Mandatory = $true, ParameterSetName = 'pats')][ValidateNotNullOrEmpty()][string]$PATS,
        [Parameter(HelpMessage = 'Version of Azure DevOps REST API', Mandatory = $true)][string] $apiVersion,
        [Parameter(HelpMessage = 'URL to the TFS project, no protocol, includes collection.', Mandatory = $true)][string] $tfsURL
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
    # else {
    #     throw "Must enter a PATS or credential to make the call to TFS!"
    # }

    try {
        Write-Verbose "Now fetching status for build id: $BuildID"
        $TFSBaseURL = "$($TfsServerUrl)/_apis/build/builds/$($BuildID)?api-version=$apiVersion"
        $webParams = @{
            Uri         = $TFSBaseURL
            Method      = "GET"
            ContentType = "application/json"
            Verbose     = $VerbosePreference
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
        Throw "Can't get build status: `n$($_.Exception.Message)`nAt Line: $($_.InvocationInfo.ScriptLineNumber)"
    }
}

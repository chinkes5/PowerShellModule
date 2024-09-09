function Get-TFSrelatedTickets {
    <#
.SYNOPSIS
Retrieves all related tickets for a given TFS work item ID.
.DESCRIPTION
The `Get-TFSrelatedTickets` function fetches all the related tickets for a given TFS work item ID by making a REST API call to the TFS server. It requires valid TFS credentials to authenticate with the server.
.PARAMETER TFSID
The ID of the TFS work item for which to fetch the related tickets. This parameter is mandatory.
.PARAMETER Credential
The credentials for the TFS server. This parameter is mandatory and should be of type `PSCredential`.
.PARAMETER PATS
A PATS token to use to authenticate the request when sent to TFS server
.PARAMETER tfsURL
URL to the TFS project, no protocol, includes collection.
.PARAMETER apiVersion
Version of Azure DevOps REST API
.EXAMPLE
PS> Get-TFSrelatedTickets -TFSID "12345" -Credential $credential

This example retrieves all the related tickets for the TFS work item with the ID "12345", using the specified credentials.
.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TFSID,
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

    try {
        Write-Verbose "Now fetching all related tickets for TFSID: $TFSID"

        $TFSBaseURL = "$($TfsServerUrl)/_apis/wit/workitems/$($TFSID)?`$expand=all"

        if ([string]::IsNullOrEmpty($PATS)) {
            $TFSBaseURLContents = Invoke-RestMethod -Uri $TFSBaseURL -Credential $Credential
        }
        else {
            $TFSBaseURLContents = Invoke-RestMethod -Uri $TFSBaseURL -Header $Header -ContentType "application/json" -Method Get
        }
        $LinkTypesRelated = $TFSBaseURLContents.relations.Where({ $_.rel -eq 'System.LinkTypes.Related' }) | Select-Object -ExpandProperty url
        Write-Verbose "TFSID: $TFSID has $($LinkTypesRelated.Count) linked ticket(s)"

        $linkedTFSTicket = @()
        foreach ($linkedTFS in $LinkTypesRelated) {
            $linkedTFSTicket += [PSCustomObject]@{
                TFSID = $linkedTFS.split('/')[-1].Trim()
                Link  = $linkedTFS
            }
        }
        return $linkedTFSTicket
    }
    catch {
        Throw "Can't get related tickets: `n$($_.Exception.Message)`nAt Line: $($_.InvocationInfo.ScriptLineNumber)"
    }
}

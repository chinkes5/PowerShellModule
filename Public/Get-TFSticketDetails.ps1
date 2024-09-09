function Get-TFSticketDetails {
    <#
.SYNOPSIS
Retrieves details for a TFS ticket.
.DESCRIPTION
The `Get-TFSticketDetails` function retrieves details for a specified TFS ticket. It uses the TFS REST API to fetch the details from the TFS server.
.PARAMETER TFSID
The ID of the TFS ticket to retrieve details for. This parameter is mandatory.
.PARAMETER Credential
The credentials for the TFS server. This parameter is mandatory.
.PARAMETER PATS
A PATS token to use to authenticate the request when sent to TFS server
.NOTES
- The TFS server URL is hardcoded inside the function and may need to be modified to match your TFS server.
- The function relies on the TFS REST API, so ensure that the API is accessible from the machine running the script.
.PARAMETER tfsURL
URL to the TFS project, no protocol, includes collection.
.PARAMETER apiVersion
Version of Azure DevOps REST API
.EXAMPLE
PS> Get-TFSticketDetails -TFSID "12345" -Credential $credential

This example retrieves details for the TFS ticket with ID "12345" using the specified credentials.
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

    #TODO: Add TFS Server details from config file
    $TfsServerUrl = "https://mdvaprjtfsvm01.compass.md.rpe/MDCompass/Compass"
    if (($null -eq $Credential) -and ($null -ne $PATS)) {
        $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($PATS)"))
        $Header = @{authorization = "Basic $token" }
    }

    try {
        Write-Verbose "Now fetching all details for TFSID: $TFSID"

        $TFSBaseURL = "$($TfsServerUrl)/_apis/wit/workitems/$($TFSID)?`$expand=all"

        if ([string]::IsNullOrEmpty($PATS)) {
            $TFSBaseURLContents = Invoke-RestMethod -Uri $TFSBaseURL -Credential $Credential
            $TFSCommentsURLContents = Invoke-RestMethod -Uri $TFSBaseURLContents._links.workItemComments.href -Credential $Credential
        }
        else {
            $TFSBaseURLContents = Invoke-RestMethod -Uri $TFSBaseURL -Header $Header -ContentType "application/json" -Method Get
            $TFSCommentsURLContents = Invoke-RestMethod -Uri $TFSBaseURLContents._links.workItemComments.href -Header $Header -ContentType "application/json" -Method Get
        }

        return [PSCustomObject]@{
            #TODO: make a little more open as we don't know what fields other sites use?
            Title                 = $TFSBaseURLContents.fields.'System.Title'
            ID                    = $TFSBaseURLContents.ID
            WorkItemType          = $TFSBaseURLContents.fields.'System.WorkItemType'
            State                 = $TFSBaseURLContents.fields.'System.State'
            AssignedTo            = $TFSBaseURLContents.fields.'System.AssignedTo'.displayName
            AssignedTo_uniqueName = $TFSBaseURLContents.fields.'System.AssignedTo'.uniqueName
            workItemComments      = $TFSCommentsURLContents.comments
            url                   = $TFSBaseURLContents.url
            fields                = $TFSBaseURLContents.fields
            Tags                  = $TFSBaseURLContents.fields.'System.Tags'
            IterationPath         = $TFSBaseURLContents.fields.'System.IterationPath'
        }
    }
    catch {
        Throw "Can't get ticket details: `n$($_.Exception.Message)`nAt Line: $($_.InvocationInfo.ScriptLineNumber)"
    }
}

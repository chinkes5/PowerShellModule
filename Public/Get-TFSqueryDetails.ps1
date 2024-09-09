function Get-TFSqueryDetails {
    <#
.SYNOPSIS
Gets the details of TFS work items based on a TFS query.
.DESCRIPTION
The `Get-TFSqueryDetails` function fetches the details of TFS work items based on a TFS query. It uses the TFS REST API to retrieve the work items and their details.
This function depends on the following functions: Get-TFSticketDetails
.PARAMETER TFSquery
The TFS query for fetching the work items. This parameter is mandatory.
.PARAMETER Credential
The credentials for accessing the TFS server. This parameter should be of type `PSCredential`.
.PARAMETER PATS
A PATS token to use to authenticate the request when sent to TFS server
.PARAMETER tfsURL
URL to the TFS project, no protocol, includes collection.
.PARAMETER apiVersion
Version of Azure DevOps REST API
.EXAMPLE
$cred = Get-Credential
Get-TFSqueryDetails -TFSquery "MyQuery" -Credential $cred

This example retrieves the details of TFS work items using the "MyQuery" TFS query and the provided credentials.
.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TFSquery,
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
        Write-Verbose "Now fetching all tickets for query: $TFSquery"

        $TFSBaseURL = "$($TfsServerUrl)/_apis/wit/wiql/$TFSquery"
        if ([string]::IsNullOrEmpty($PATS)) {
            $TFSBaseURLContents = Invoke-RestMethod -Uri $TFSBaseURL -Credential $Credential
        }
        else {
            $TFSBaseURLContents = Invoke-RestMethod -Uri $TFSBaseURL -Header $Header -ContentType "application/json" -Method Get
        }
        $QueryResults = @()
        foreach ($TFSID in $TFSBaseURLContents.workItems) {
            if ([string]::IsNullOrEmpty($PATS)) {
                $return = Get-TFSticketDetails -TFSID $TFSID.ID -Credential $Credential
            }
            else {
                $return = Get-TFSticketDetails -TFSID $TFSID.ID -PATS $PATS
            }

            $item = [PSCustomObject]@{
                ID               = $return.ID
                'Work Item Type' = $return.WorkItemType
                Title            = $return.Title
                'Assigned To'    = $return.AssignedTo
                State            = $return.State
                #'Manual Steps'   = $manualSetp
                'Iteration Path' = $return.fields.'System.IterationPath'
                # Tags =
            }
            $QueryResults += $item
        }

        return $QueryResults
    }
    catch {
        Throw "Cannot get query details: `n$($_.Exception.Message)`nAt Line: $($_.InvocationInfo.ScriptLineNumber)"
    }
}

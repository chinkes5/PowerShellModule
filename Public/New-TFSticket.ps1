function New-TFSticket {
    <#
.SYNOPSIS
Creates a new TFS work item with specified details.
.DESCRIPTION
The `New-TFSticket` function creates a new work item in TFS with the provided details. It uses the TFS REST API to send a POST request to the TFS server.
.PARAMETER apiVersion
Version of Azure DevOps REST API
.PARAMETER completionDate
The due date of the ticket. This parameter is optional.
.PARAMETER Credential
The credentials for the TFS server. This parameter is mandatory.
.PARAMETER PATS
A PATS token to use to authenticate the request when sent to TFS server
.PARAMETER tfsType
The ticket type as defined in TFS. This parameter is optional.
.PARAMETER tfsURL
URL to the TFS project, no protocol, includes collection.
.PARAMETER workItemDescription
The description to add to the TFS work item. This parameter is optional.
.PARAMETER workItemTitle
The title of the TFS work item. This parameter is mandatory.
.EXAMPLE
PS> New-TFSticket -workItemTitle "Bug fix" -Credential $credential -workItemDescription "Fixes a critical bug in the application"

This example creates a new TFS work item with the title "Bug fix", using the specified credentials and description.
.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/
#>
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage = 'Version of Azure DevOps REST API', Mandatory = $true)][string] $apiVersion,
        [Parameter(HelpMessage = 'The due date of the ticket')][datetime]$completionDate,
        [Parameter(Mandatory = $true, ParameterSetName = 'cred')][ValidateNotNullOrEmpty()][PSCredential]$Credential,
        [Parameter(Mandatory = $true, ParameterSetName = 'pats')][ValidateNotNullOrEmpty()][string]$PATS,
        [Parameter(HelpMessage = 'The ticket type as defined in TFS')][string]$tfsType,
        [Parameter(HelpMessage = 'URL to the TFS project, no protocol, includes collection.', Mandatory = $true)][string] $tfsURL,
        [Parameter(HelpMessage = 'Any description to add to the TFS work item')][string]$workItemDescription,
        [Parameter(Mandatory = $true, HelpMessage = 'The title of the TFS work item')][ValidateNotNullOrEmpty()][string]$workItemTitle
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
        $TFStype = [uri]::EscapeDataString("Tech Team Ticket")

        $TFSBaseURL = "$($TfsServerUrl)/_apis/wit/workitems/`$$($TFStype)?api-version=$apiVersion"
        $body = @(
            @{
                op    = "add"
                path  = "/fields/System.Title"
                from  = "null"
                value = "$workItemTitle"
            },
            @{
                op    = "add"
                path  = "/fields/System.Description"
                value = "$workItemDescription"
            }
        )
        Write-Verbose "Creating ticket titled: '$workItemTitle'"
        $webParams = @{
            Uri         = $TFSBaseURL
            Method      = "Post"
            Body        = "$($body | ConvertTo-Json)"
            ContentType = "application/json-patch+json"
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
        Throw "There was an error creating the ticket: `n$($_.Exception.Message)`nAt Line: $($_.InvocationInfo.ScriptLineNumber)"
    }
}
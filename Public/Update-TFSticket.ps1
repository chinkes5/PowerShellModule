function Update-TFSticket {
    <#
.SYNOPSIS
Updates TFS work item with specified details.
.DESCRIPTION
The `Update-TFSticket` function creates a new work item in TFS with the provided details. It uses the TFS REST API to send a POST request to the TFS server.
.PARAMETER Credential
The credentials for the TFS server. This parameter is mandatory.
.PARAMETER PATS
A PATS token to use to authenticate the request when sent to TFS server
.PARAMETER tfsURL
URL to the TFS project, no protocol, includes collection.
.PARAMETER apiVersion
Version of Azure DevOps REST API
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TFSID,
        [Parameter(Mandatory = $true, ParameterSetName = 'cred')][ValidateNotNullOrEmpty()][PSCredential]$Credential,
        [Parameter(Mandatory = $true, ParameterSetName = 'pats')][ValidateNotNullOrEmpty()][string]$PATS,
        [Parameter(HelpMessage = 'A description of the resolution to the TFS work item')][string]$Resolution,
        [Parameter(HelpMessage = 'Unique Name of the user to assign the ticket to')][string]$User,
        [Parameter(HelpMessage = 'The state to assign the ticket to')][string]$State, # figure out the list of acceptable answers and validate for that
        [Parameter(HelpMessage = 'A SQL file to attach to ticket, must have TFS ID in script!')][System.IO.FileInfo]$InputFile,
        [Parameter(HelpMessage = 'A comment to add to the TFS work item')][string]$Comment,
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
        $TFSBaseURL = "$($TfsServerUrl)/_apis/wit/workitems/$($TFSID)?api-version=$apiVersion"
        $body = @()

        if (![string]::IsNullOrEmpty($user)) {
            Write-Verbose "Reassigning ticket to different user..."
            $body += @{
                op    = "replace"
                path  = "/fields/System.AssignedTo"
                value = "$user"
            }
        }
        if (![string]::IsNullOrEmpty($State)) {
            Write-Verbose "Changing state of ticket..."
            $body += @{
                op    = "replace"
                path  = "/fields/System.State"
                value = "$state"
            }
        }
        if (![string]::IsNullOrEmpty($InputFile)) {
            ##### not sure this is going to work, need review and probable refactor #####
            Write-Verbose "Upload process will try to upload file: $inputFile to TFS: $TFSID"
            if ([string]::IsNullOrEmpty($PATS)) {
                $attachedFileName = Upload-FileToTFS -TfsServerUrl $TfsServerUrl -InputFile $InputFile -Credential $Credential
            }
            else {
                $attachedFileName = Upload-FileToTFS -TfsServerUrl $TfsServerUrl -InputFile $InputFile -Pats $PATS
                # TODO: am I getting back what I need? Look at the unused var below!
            }

            #once uploaded, we use the output of that to put a note into the ticket
            $url = $uploads.Content.ToString()
            $url -match "https://(.+?)}"
            $actualURL = $Matches[1].ToString().Replace('"', '')
            # update the URL based on the captured filename
            $attachmentURI = $actualURL
            Write-Verbose "Adding the file upload to ticket discussion..."
            $body += @{
                op    = "add"
                path  = "/fields/System.History"
                value = $uploadText #<- where is this created?
            }
            Write-Verbose "Attaching file to ticket..."
            $body += @{
                op    = "add"
                path  = "/relations/-"
                value = @{
                    rel        = "AttachedFile"
                    url        = $attachmentURI
                    attributes = @{
                        comment = $uploadText
                    }
                }
            }
            # these two things get added to the ticket, like any of the other inputted object, below
        }
        if (![string]::IsNullOrEmpty($Comment)) {
            Write-Verbose "Adding comment to ticket..."
            $body += @{
                op    = "add"
                path  = "/fields/System.History"
                value = "$Comment"
            }
        }

        Write-Verbose "Updating ticket: '$TFSID'"
        $webParams = @{
            Uri         = $TFSBaseURL
            Method      = "Patch"
            Body        = "$(ConvertTo-Json -InputObject $body -Depth 3)"
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
        Throw "There was an error updating the ticket: `n$($_.Exception.Message)`nAt Line: $($_.InvocationInfo.ScriptLineNumber)"
    }
}
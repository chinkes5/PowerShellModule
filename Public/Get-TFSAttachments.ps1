function Get-TFSAttachments {
    <#
.SYNOPSIS
Retrieves SQL file attachments from a TFS item.
.DESCRIPTION
The Get-TFSAttachments function is used to fetch attachments from a TFS (Team Foundation Server) item. It requires at least three parameters: TFSID, Credential, and OutputFolder. The function retrieves the attachment URLs and names from the specified TFS item and then downloads the SQL file attachments to the specified output folder.
The function currently supports downloading attachments that have a ".sql" file extension. Attachments with other file extensions will be skipped.
.PARAMETER TFSID
Specifies the ID of the TFS item from which to retrieve attachments. This parameter is mandatory.
.PARAMETER Credential
Specifies the user's credentials to authenticate with the TFS server. This parameter is mandatory and should be of type PSCredential.
.PARAMETER PATS
A PATS token to use to authenticate the request when sent to TFS server
.PARAMETER OutputFolder
Specifies the folder where the attachments will be saved. This parameter is optional but should be a valid folder path when provided.
.PARAMETER SkipDownload
Switch parameter to set when only the attachments name and URL are desired, no output files needed in the OutputFolder
.PARAMETER tfsURL
URL to the TFS project, no protocol, includes collection.
.PARAMETER apiVersion
Version of Azure DevOps REST API
.EXAMPLE
Get-TFSAttachments -TFSID "12345" -Credential $Credential -OutputFolder "C:\Attachments"
Retrieves attachments from the TFS item with ID 12345 and saves them to the "C:\Attachments" folder.
.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TFSID,
        [Parameter(Mandatory = $true, ParameterSetName = 'cred')][ValidateNotNullOrEmpty()][PSCredential]$Credential,
        [Parameter(Mandatory = $true, ParameterSetName = 'pats')][ValidateNotNullOrEmpty()][string]$PATS,
        [Parameter(HelpMessage = 'Specifies the folder where the attachments will be saved.')][System.IO.FileInfo]$OutputFolder,
        [Parameter(HelpMessage = 'Set this when only the attachments name and URL are desired, no output files needed in the OutputFolder')][switch]$SkipDownload,
        [Parameter(HelpMessage = 'Version of Azure DevOps REST API', Mandatory = $true)][string] $apiVersion,
        [Parameter(HelpMessage = 'URL to the TFS project, no protocol, includes collection.', Mandatory = $true)][string] $tfsURL
    )

    begin {
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

        if (-not ($SkipDownload)) {
            if (Test-Path $OutputFolder -PathType Container) {
                Write-Verbose "Found Output folder!"
            }
            else {
                throw "Can't find folder to save attachments: $OutputFolder"
            }
        }
        else {
            Write-Verbose "Only getting list of SQL attachments, no download needed!"
        }
    }

    process {
        try {
            Write-Verbose "Now fetching all attachments for TFSID: $TFSID"

            # get all the attachment URLs and names from TFS
            $TFSBaseURL = "$($TfsServerUrl)/_apis/wit/workitems/$($TFSID)?`$expand=all"

            if ([string]::IsNullOrEmpty($PATS)) {
                $TFSBaseURLContents = Invoke-RestMethod -Uri $TFSBaseURL -Credential $Credential
            }
            else {
                $TFSBaseURLContents = Invoke-RestMethod -Uri $TFSBaseURL -Header $Header -ContentType "application/json" -Method Get
            }
            $Attachments = $TFSBaseURLContents.relations.Where({ $_.rel -eq 'AttachedFile' }) | Select-Object url, attributes

            # getting attachment count
            $TotalAttachmentCount = $Attachments.Count
            Write-Verbose "TFSID: $TFSID has number of attachments: $TotalAttachmentCount"

            $return = @()

            foreach ($Attachment in $Attachments) {
                $AttachmentName = $Attachment.attributes.name
                $AttachmentURL = $Attachment.url

                Write-Verbose "Looking for SQL files..."
                if ($AttachmentName.ToLower().Contains(".sql")) {
                    if ($SkipDownload) {
                        $DownloadPath = $AttachmentName
                        $FileDownloadURL = "$($AttachmentURL)?fileName=$($AttachmentName)"
                    }
                    else {
                        $DownloadPath = Join-Path $OutputFolder -ChildPath $AttachmentName
                        $FileDownloadURL = "$($AttachmentURL)?fileName=$($AttachmentName)"
                        Write-Verbose "Now downloading attachment: '$($AttachmentName)', from: '$FileDownloadURL'"
                        Invoke-WebRequest -Uri $FileDownloadURL -OutFile $DownloadPath -Credential $Credential
                    }

                    $return += @{
                        URL       = $FileDownloadURL
                        LocalFile = $DownloadPath
                    }
                }
                else {
                    Write-Verbose "Attachment will be skipped: $($AttachmentName)"
                }
            }
            Write-Verbose "All attachments fetched for TFSID: $TFSID"
            return $return
        }
        catch {
            Throw "Can't get attachments from TFS: `n$($_.Exception.Message)`nAt Line: $($_.InvocationInfo.ScriptLineNumber)"
        }
    }
}

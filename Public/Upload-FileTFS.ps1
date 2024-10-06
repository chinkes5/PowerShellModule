function Upload-FileToTFS {
    <#
.SYNOPSIS
Upload a file to TFS.
.DESCRIPTION
This command uploads a file to TFS. It takes a TFS ID, a file path, and a credential as parameters.
.PARAMETER TFSID
The ID of the TFS work item to upload the file to.
.PARAMETER InputFile
The path to the file to upload to TFS.
.PARAMETER Credential
The credentials to use to authenticate to TFS.
.PARAMETER tfsURL
URL to the TFS project, no protocol, includes collection.
.PARAMETER apiVersion
Version of Azure DevOps REST API
.EXAMPLE
Upload-FileToTFS -TFSID "SQ12345" -InputFile "C:\Path\To\File.sql" -Credential (Get-Credential)
#>

    param (
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TFSID,
        [Parameter(Mandatory = $true)][string]$InputFile,
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
        $headers = @{authorization = "Basic $token" }
    }

    $BaseName = $inputFile
    $BaseName -match "(?<date>^[0-9]{6})_(?<time>.+?)(?<database>ITP|INTR|MEF|Portal)\.(?<TFSID>MD[0-9]{5})\.(?<scriptCount>[0-9]{3}).sql"
    $ScriptID = $Matches.TFSID
    if ($TFSID -eq $ScriptID) {
        Write-Verbose "This file will be uploaded to TFS: $TFSID"
    }
    else {
        throw "File doesn't match TFS ID: $TFSID"
    }

    $attachedFileName = $inputFile.Replace('F:\TechTools\DropBox\Dev\Series\', '') # this needs to be dynamic? Notes from someone else, not sure what to do here... It might be just stripping the path from the file name. Seems like there might be a better way to do this!
    $uriUpload = "$($TfsServerUrl)/_apis/wit/attachments?fileName=$($attachedFileName)&api-version=$apiVersion"
    $body = Get-Content $inputFile -Encoding UTF8 -Raw
    if ($headers) {
        $headers.Add("Content-Type", "application/json")
    }
    else {
        $headers = @{
            "Content-Type" = "application/json"
        }
    }
    # TODO: figure out how this works... What is returned? What do I need to hand off to the calling function?
    Invoke-WebRequest -Method POST -Uri $uriUpload -Credential $c -Body $body -Headers $headers -UseBasicParsing

    return $attachedFileName
}

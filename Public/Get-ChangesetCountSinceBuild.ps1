function Get-ChangesetCountSinceBuild {
    <#
    .SYNOPSIS
    Gets the count of new changesets in the repo since the last successful build of the definition ID given
    .DESCRIPTION
    Gets the count of new changesets in the repo since the last successful build of the definition ID given
    .PARAMETER PAT
    A PAT that has access to the TFS project
    .PARAMETER BuildID
    Build definition ID to get last successful build of
    .PARAMETER RepoPath
    The path to the TFS repo
    .PARAMETER tfsURL
    URL to the TFS project, no protocol, includes collection., includes collection., includes collection.
    .PARAMETER apiVersion
    Version of Azure DevOps REST API
    .EXAMPLE
    Get-ChangesetCountSinceBuild -PAT $PATS -tfsURL $tfsURL -BuildID 188 -RepoPath 'INT' -apiVersion 1.0

    Returns a count of changesets in branch INT since the last successful build in ID 188
    #>
    param(
        [Parameter(HelpMessage = 'Version of Azure DevOps REST API', Mandatory = $true)][string] $apiVersion,
        [Parameter(HelpMessage = 'Build definition ID to get last successful build of', Mandatory = $true)][string] $BuildID,
        [Parameter(HelpMessage = 'A PAT that has access to the TFS project', Mandatory = $true)][string] $PAT,
        [Parameter(HelpMessage = 'The path to the TFS repo', Mandatory = $true)][string] $RepoPath,
        [Parameter(HelpMessage = 'URL to the TFS project, no protocol, includes collection.', Mandatory = $true)][string] $tfsURL
    )

    Write-Verbose "Preparing authentication headers for TFS REST api..."
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$PAT"))
    $Header = @{authorization = "Basic $token" }

    $Uri = "https://$tfsURL/_apis/build/builds/?definitions=$BuildID&resultFilter=succeeded&api-version=$apiVersion"
    Write-Verbose "Getting list of builds for $BuildID..."
    $build = Invoke-RestMethod -Method 'Get' -Uri $Uri -ContentType "application/json" -Headers $header

    Write-Verbose "Filter results to get Queue time of last successful build"
    $LastBuildQueueTime = ($build.value | Sort-Object queuetime -desc | Select-Object -first 1 ).queuetime

    try {
        Write-Verbose "From all of the Changesets only select changes where creationdate is greater than the queue time of the last successful build"
        $Uri = "https://$tfsURL/_apis/tfvc/changesets/?api-version=$apiVersion&searchCriteria.itemPath=$RepoPath"
        $changesets = Invoke-RestMethod -Method 'Get' -Uri $Uri -ContentType "application/json" -Headers $header
        $RunCoreReplace = ($changesets.value | Where-Object { [datetime]$_.createddate -gt [datetime]$LastBuildQueueTime } | measure-object).Count
    }
    catch {
        $RunCoreReplace = 1;
        if ( $_ -match "convert null") {
            throw "Err has been thrown that cannot convert null for build queue time. Meaning it's never ran successfully."
        }
        else {
            Write-host "ERR: $($_)"
        }
    }

    return [int]($RunCoreReplace)
}

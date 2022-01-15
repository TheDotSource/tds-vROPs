function Set-vROPsGroupPolicy {
    <#
    .SYNOPSIS
        Apply a policy to a custom group.

    .DESCRIPTION
        Apply a policy to a custom group.

    .PARAMETER vROPSCon
        A vROPs connection object as created by Connect-vROPs

    .PARAMETER policyName
        Name of policy to apply to the custom group.

    .PARAMETER customGroup
        The name of the group to query the policy for.

    .INPUTS
        vropsConnection. A vROPs connection object.

    .OUTPUTS
        None.

    .EXAMPLE
        Set-vROPsGroupPolicy -vROPSCon $vRopsCon -customGroup CustomGroup -policyName TEST-POLICY

        Apply policy TEST-POLICY to group CustomGroup using the vRops connection $vRopsCon

    .LINK

    .NOTES

    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Medium")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [vropsConnection]$vROPSCon,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$customGroup,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$policyName
    )

    begin {

        Write-Verbose ("Starting function.")

    } # begin

    process {

        ## Define headers for HTTP requests
        $headers = @{}
        $headers.Add("Accept", "application/json")
        $headers.Add("Content-Type", "application/json")
        $headers.Add("Authorization", ("vRealizeOpsToken " + $vROpsCon.authToken))

        ## Add unsupported header as some calls go to internal API
        $headers.Add("X-vRealizeOps-API-use-unsupported", "true")

        ## Get policy collection from this node. We need this to lookup IDs later
        $Uri = ("https://" + $vROPSCon.vROPSNode + "/suite-api/internal/policies")


        Write-Verbose ("Fetching policies.")


        ## Get policies from this vROPs node
        try {
            $vropsPolicies = Invoke-RestMethod -Uri $Uri -Method Get -Headers $headers -SkipCertificateCheck:$vROPSCon.skipCertificates -ErrorAction Stop
            Write-Verbose ("Got list of policies and GUIDs from API.")
        } # try
        catch {
            throw ("Failed to get policies, the CMDlet returned " + $_.exception.message)
        } # catch


        ## Match this ID to previously extracted list of policies
        $policyDetails = $vropsPolicies.'policy-summaries' | Where-Object {$_.name -eq $policyName}


        ## Check we have 1 matching policy
        if (($policyDetails | Measure-Object).count -ne 1) {
            throw ("The specfied policy " + $policyName + " was not found on this vROPs node.")
        } # if


        ## Set url for request
        $Uri = ("https://" + $vROPSCon.vROPSNode + "/suite-api/api/resources/groups?includePolicy=true")


        ## Get collection of custom groups from API
        try {
            $customGroups = Invoke-RestMethod -Uri $Uri -Method Get -Headers $headers -SkipCertificateCheck:$vROPSCon.skipCertificates -ErrorAction Stop
            Write-Verbose ("Got list of custom groups from API.")
        } # try
        catch {
            throw ("Failed to get list of custom groups, the CMDlet returned " + $_.exception.message)
        } # catch


        ## Get group object by name
        $groupObj = $customGroups.groups | Where-Object {$_.resourceKey.name -eq $customGroup}


        ## Check there is 1 group matching this name
        if (($groupObj | Measure-Object).count -ne 1) {
            throw ("The specfied custom group " + $customGroup + " was not found on this vROPs node.")
        } # if


        Write-Verbose ("Found group " + $customGroup)


        ## Switch through various possibilities and set accordingly
        switch ($groupObj.policy) {

            {$_ -eq $null} {
                Write-Verbose ("No policy associated with this group, specified policy will be applied.")
                $groupObj | Add-Member -MemberType NoteProperty -Name "policy" -Value $policyDetails.id

            } # no policy applied

            {$_ -eq $policyDetails.id} {
                Write-Verbose ("Group already has " + $policyName + " applied. No further action is necessary.")
                Return

            } # policy matches

            default {
                Write-Verbose ("Group already has policy with GUID " + $groupObj.policy + " applied. It will be changed.")
                $groupObj.policy = $policyDetails.id

            } # default

        } # switch


        ## PUT this back to the API to update policy GUID
        $Uri = ("https://" + $vROPSCon.vROPSNode + "/suite-api/api/resources/groups")


        ## Get collection of custom groups from API
        try {

            ## Apply shouldProcess
            if ($PSCmdlet.ShouldProcess($customGroup)) {
                $customGroups = Invoke-RestMethod -Uri $Uri -Method Put -Headers $headers -Body ($groupObj | ConvertTo-Json -Depth 5) -SkipCertificateCheck:$vROPSCon.skipCertificates -ErrorAction Stop
            } # if

            Write-Verbose ("Group was updated with new policy details.")
        } # try
        catch {
            throw ("Failed to update group with new policy, the CMDlet returned " + $_.exception.message)
        } # catch


    } # process


    end {

        Write-Verbose ("Function complete.")
    } # end


} # function
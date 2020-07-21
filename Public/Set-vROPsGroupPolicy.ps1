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
        01           Alistair McNair          Initial version.
        02           Alistair McNair          Replaced Basic Auth with token based authentication.

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

        ## Ignore invalid certificates
        if (!([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
            Add-Type @"
            using System.Net;
            using System.Security.Cryptography.X509Certificates;
            public class TrustAllCertsPolicy : ICertificatePolicy {
                public bool CheckValidationResult(
                    ServicePoint srvPoint, X509Certificate certificate,
                    WebRequest request, int certificateProblem) {
                    return true;
                }
            }
"@

            [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy -ErrorAction SilentlyContinue

            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        } # if

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
            $vropsPolicies = Invoke-RestMethod -Uri $Uri -Method Get -Headers $headers -ErrorAction Stop
            Write-Verbose ("Got list of policies and GUIDs from API.")
        } # try
        catch {
            Write-Debug ("Failed to get policies.")
            throw ("Failed to get policies, the CMDlet returned " + $_.exception.message)
        } # catch


        ## Match this ID to previously extracted list of policies
        $policyDetails = $vropsPolicies.'policy-summaries' | Where-Object {$_.name -eq $policyName}


        ## Check we have 1 matching policy
        if (($policyDetails | Measure-Object).count -ne 1) {
            Write-Debug ("Policy not found.")
            throw ("The specfied policy " + $policyName + " was not found on this vROPs node.")
        } # if


        ## Set url for request
        $Uri = ("https://" + $vROPSCon.vROPSNode + "/suite-api/api/resources/groups?includePolicy=true")


        ## Get collection of custom groups from API
        try {
            $customGroups = Invoke-RestMethod -Uri $Uri -Method Get -Headers $headers -ErrorAction Stop
            Write-Verbose ("Got list of custom groups from API.")
        } # try
        catch {
            Write-Debug ("Failed to get list of custom groups.")
            throw ("Failed to get list of custom groups, the CMDlet returned " + $_.exception.message)
        } # catch


        ## Get group object by name
        $groupObj = $customGroups.groups | Where-Object {$_.resourceKey.name -eq $customGroup}


        ## Check there is 1 group matching this name
        if (($groupObj | Measure-Object).count -ne 1) {
            Write-Debug ("Custom group not found.")
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
                $customGroups = Invoke-RestMethod -Uri $Uri -Method Put -Headers $headers -Body ($groupObj | ConvertTo-Json -Depth 5) -ErrorAction Stop
            } # if

            Write-Verbose ("Group was updated with new policy details.")
        } # try
        catch {
            Write-Debug ("Failed to update group.")
            throw ("Failed to update group with new policy, the CMDlet returned " + $_.exception.message)
        } # catch


    } # process


    end {

        Write-Verbose ("Function complete.")
    } # end


} # function
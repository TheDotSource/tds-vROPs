function Get-vROPsGroupPolicy {
    <#
    .SYNOPSIS
        Return the policy associated with the specified group, if any.

    .DESCRIPTION
        Pull down a list of custom groups from the API, filter by name, find the applied policy GUID (if any).
        Lookup policy GUID to get name.
        Return group object with associated policy name and ID.

    .PARAMETER vROPSNode
        The target vROPs node to perform an import on. Can be pipelined.

    .PARAMETER Credential
        PowerShell credential object with appropriate permissions for policy import.

    .PARAMETER customGroup
        The name of the group to query the policy for.

    .INPUTS
        System.String. vROPs node names can be piped to this function.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. Returns a group object with associated policy details.

    .EXAMPLE
        Get-vROPsGroupPolicy -vROPSNode vrops01.lab.local -Credential $creds -customGroup "CustomGroup1"

        Return the policy applied to CustomGroup1 on vROPs node vrops01.lab.local

    .LINK
        
    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vROPSNode,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$customGroup,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential
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

        ## Define headers for HTTP requests
        $headers = @{}
        $headers.Add("Accept", "application/json")
        $headers.Add("Content-Type", "application/xml;charset=utf-8")

        ## Add unsupported header as some calls go to internal API
        $headers.Add("X-vRealizeOps-API-use-unsupported", "true")

    } # begin

    process {

        Write-Verbose ("Processing vROPS node " + $vROPSNode)


        ## Get policy collection from this node. We need this to lookup IDs later
        $Uri = ("https://" + $vROPSNode + "/suite-api/internal/policies")


        Write-Verbose ("Fetching policies.")


        ## Get policies from this vROPs node
        try {
            $vropsPolicies = Invoke-RestMethod -Uri $Uri -Method Get -Headers $headers -Credential $Credential -ErrorAction Stop
            Write-Verbose ("Got list of policies and GUIDs from API.")
        } # try
        catch {
            Write-Debug ("Failed to get policies.")
            throw ("Failed to get policies, the CMDlet returned " + $_.exception.message)
        } # catch


        ## Set url for request
        $Uri = ("https://" + $vROPSNode + "/suite-api/api/resources/groups?includePolicy=true")


        ## Get collection of custom groups from API
        try {
            $customGroups = Invoke-RestMethod -Uri $Uri -Method Get -Headers $headers -Credential $Credential -ErrorAction Stop
            Write-Verbose ("Got list of custom groups from API.")
        } # try
        catch {
            Write-Debug ("Failed to get list of custom groups.")
            throw ("Failed to get list of custom groups, the CMDlet returned " + $_.exception.message)
        } # catch


        ## Get group object by name
        $groupObj = $customGroups.groups | where {$_.resourceKey.name -eq $customGroup}


        ## Check there is 1 group matching this name. If not warn and return null.
        if (($groupObj | Measure-Object).count -ne 1) {
            Write-Warning ("The specfied custom group " + $customGroup + " was not found on this vROPs node.")
            return $null
        } # if


        Write-Verbose ("Found group " + $customGroup)
        

        ## Check what policy is associated with this group
        if ($groupObj.policy.count -eq 0) {

            Write-Verbose ("No policies are associated with this group.")

            ## Initialise object for this group
            $groupPolicy = [pscustomobject]@{"vopsNode" = $vROPSNode; "groupName" = $customGroup; "groupId" = $groupObj.id; "policyName" = $null; "policyId" = $null}

        } # if
        else {

            ## Match this ID to previously extracted list of policies
            $policyDetails = $vropsPolicies.'policy-summaries' | where {$_.id -eq $groupObj.policy}

            Write-Verbose ("Group has a policy " + $policyDetails.name + " applied.")

            ## Initialise object for this group
            $groupPolicy = [pscustomobject]@{"vopsNode" = $vROPSNode; "groupName" = $customGroup; "groupId" = $groupObj.id; "policyName" = $policyDetails.name; "policyId" = $policyDetails.id}

        } # else


        return $groupPolicy

    } # process


    end {

        Write-Verbose ("Function complete.")
    } # end


} # function
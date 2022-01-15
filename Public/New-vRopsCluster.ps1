function New-vRopsCluster {
    <#
    .SYNOPSIS
        Initialise a new vRops cluster.

    .DESCRIPTION
        Initialise a new vRops cluster with a master and replica node using the CaSa API.

        Will return a response object with a link to track cluster creation progress.

    .PARAMETER masterName
        The name of the master node.

    .PARAMETER masterIp
        The IP of the master node.

    .PARAMETER replicaName
        The name of the replica node.

    .PARAMETER replicaIp
        The IP of the replica node.

    .PARAMETER ntp
        NTP server(s) to use.

    .PARAMETER adminCred
        The vRops admin credential to set.

    .INPUTS
        None.

    .OUTPUTS
        System.Management.Automation.PSCustomObject.

    .EXAMPLE
        New-vRopsCluster -masterName podvro01 -masterIp 10.10.1.101 -replicaName podvr02 -replicaIp 10.10.1.102 -ntp 10.10.1.20 -adminCred $creds

        Initialise a new cluster with podvr01 as the master and podvr02 as the replica.

    .LINK

    .NOTES

    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$masterName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$masterIp,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [string]$replicaName,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [string]$replicaIp,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string[]]$ntp,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$adminCred
    )

    begin {
        Write-Verbose ("Function start.")

    } # begin

    process {

        ## Every cluster must have a master, start with that configuration
        Write-Verbose ("Fetching thumbprint for master appliance.")

        try {
            $masterThumb = Get-NodeThumbprint -targetNode $masterIp -thumbprintFormat colon
            Write-Verbose ("Thumbprint is " + $masterThumb)
        } # try
        catch {
            throw ("Failed to get thumbprint for master appliance, verify the node is online. " + $_.Exception.Message)
        } # catch


        ## Extract password from passed credential object
        $adminPassword = $adminCred.GetNetworkCredential().Password

        ## Format NTP string from array
        $ntpString = (("`"") + ($ntp -join "`",`"") + ("`""))

        $reqTemplate = @"
{
    "master" : {
        "name" : "$masterName",
        "address" : "$masterIp",
        "thumbprint" : "$masterThumb"
    },

"@


        ## Check to see if a Replica appliance has been specified.
        if ($replicaName) {
            Write-Verbose ("Fetching thumbprint for replica appliance.")

            try {
                $replicaThumb = Get-NodeThumbprint -targetNode $replicaIp -thumbprintFormat colon
                Write-Verbose ("Thumbprint is " + $masterThumb)
            } # try
            catch {
                throw ("Failed to get thumbprint for replica appliance, verify the node is online. " + $_.Exception.Message)
            } # catch


            ## Append replica config to the request template
            $reqTemplate += @"
    "replica" : {
        "name" : "$replicaName",
        "address" : "$replicaIp",
        "thumbprint" : "$replicaThumb"
        },

"@

        } # if

        ## Add common config at the end of the request
        $reqTemplate += @"
    "admin_password" : "$adminPassword",
    "ntp_servers" : [$ntpString],
    "init" : true,
    "dry-run" : false
}
"@


        ## Send request to CaSa API to initialise the cluster. Skip certificates as we will likely still be using self signed at this stage.
        Write-Verbose ("Starting cluster initialisation.")
        try {
            $request = Invoke-RestMethod -Method Post -ContentType "application/json;charset=UTF-8" -Body $reqTemplate -Uri ("https://" + $masterIp + "/casa/cluster") -SkipCertificateCheck
            Write-Verbose ("Cluster initialisation has started.")
        } # Try
        catch {
            throw ("Cluster creation failed. " + $_.Exception.Message)
        } # Catch


        ## Return the request response, this might contain some useful information
        return $request

    } # process

    end {
        Write-Verbose ("Function complete.")

    } # end

} # function
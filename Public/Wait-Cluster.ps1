function Wait-Cluster {
    <#
    .SYNOPSIS
        Wait for a vRops cluster to reach an initialised state.

    .DESCRIPTION
        Wait for a vRops cluster to reach an initialised state.

        Useful after initial cluster creation.

    .PARAMETER vrops
        The target vRops appliance to test cluster status.

    .PARAMETER timeout
        A time out value in seconds.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Wait-Cluster -vrops 10.10.1.100 -timeout 300

        Wait for the cluster to intialise using CaSa cluster status on 10.10.1.100.

    .LINK

    .NOTES

    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vrops,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [int]$timeout,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential
    )


    begin {
        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Waiting for cluster to become ready.")

        $startTime = Get-Date

        while ($clusterStatus.cluster_state -ne "INITIALIZED") {

            ## Check if timeout has been exceeded
            if ($startTime -lt (Get-Date).AddSeconds(-$timeout)) {
                throw ("The cluster failed to initialise within the specified timeout period - (" + $timeout + ") seconds.")
            } # if


            ## Poll the endpoint
            try {
                $clusterStatus = Invoke-RestMethod -Method Get -Uri ("https://" + $vrops + "/casa/cluster/status") -Credential $Credential -SkipCertificateCheck -ErrorAction Stop
            } # try
            catch {
                Write-Warning ("Failed to contact cluster status endpoint.")
            } # catch

            ## Wait cycle before next poll
            Start-Sleep 20

        } # while

        ## Get time of completion so we know how long this took
        $completion = Get-Date

        ## How long did this take?
        $duration = (New-TimeSpan -Start $startTime -End $completion).Seconds

        Write-Verbose ("Cluster initialisation has completed and took " + $duration + " seconds.")

    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function
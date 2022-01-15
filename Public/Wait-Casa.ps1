function Wait-Casa {
    <#
    .SYNOPSIS
        Wait for the vRops CaSa API to become available.

    .DESCRIPTION
        Wait for the vRops CaSa API to become available.

        Useful after initial deployment or restart of the appliance.

    .PARAMETER vrops
        The target vRops appliance to test.

    .PARAMETER timeout
        A time out value in seconds.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Wait-Casa -vrops 10.10.1.100 -timeout 300

        Wait for the CaSa API at 10.10.1.100 to become available.

    .LINK

    .NOTES

    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vrops,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [int]$timeout
    )

    begin {
        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing appliance " + $vrops)

        $startTime = Get-Date

        ## Without authentication we wait for a 415 code from the following endpoint
        Write-Verbose ("Waiting for CaSa API to become available for a maximum of " + $timeout + " seconds.")

        while ($returnCode -ne "415") {

            ## Check if timeout has been exceeded
            if ($startTime -lt (Get-Date).AddSeconds(-$timeout)) {
                throw ("Failed to get a response from " + $vcsa + " within the specified timeout period - (" + $timeout + ") seconds.")
            } # if


            ## Poll the endpoint
            try {
                Invoke-WebRequest -Uri ("https://" + $vrops + "/casa/cluster") -Method Post -SkipCertificateCheck | Out-Null
            } # try
            catch {
                $returnCode = $_.Exception.Response.StatusCode.Value__
            } # catch

            ## Wait cycle before next poll
            Start-Sleep 10

        } # while

        Write-Verbose ("Completed appliance " + $vrops)

    } # process

    end {
        Write-Verbose ("Function end.")

    } # end

} # function
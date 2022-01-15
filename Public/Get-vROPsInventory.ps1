function Get-vROPsInventory {
    <#
    .SYNOPSIS
        Return a list of objects managed by the specified vrops instance.

    .DESCRIPTION
        Return a list of objects managed by the specified vrops instance.
        Object type requires to be spcified, i.e. host, virtual machine etc.
        Only objects collected by adapter type VMWARE are returned.

        Result page size is 1000, if more than 1000 results are returned, paginated queries will be performed.

    .PARAMETER vROPSCon
        A vROPs connection object as created by Connect-vROPs

    .PARAMETER ObjectType
        The specified object type to query for.

    .PARAMETER adapterType
        The vrops adapter type to use.

    .INPUTS
        vropsConnection. A vROPs connection object.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. A collection of objects returned from the query.

    .EXAMPLE
        Get-vROPsInventory -vROpsCon $vropsCon -objectType hostSystem -adapterType VMWARE

        Get all hosts collected by the adapter type VMWARE using the vRops connection object $vropscon

    .LINK

    .NOTES

    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [vropsConnection]$vROpsCon,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("VirtualMachine","HostSystem","Datastore")]
        [string]$objectType,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("VMWARE")]
        [string]$adapterType
    )

    begin {
        Write-Verbose ("Function start.")

    } # begin


    process {
        Write-Verbose ("Processing node " + $vROpsCon.vropsnode)

        ## Set headers for this node with appropriate token
        $headers = @{}
        $headers.Add("Authorization", ("vRealizeOpsToken " + $vROpsCon.authToken))
        $headers.Add("ContentType", "application/json")
        $headers.Add("Accept", "application/json")


        ## Send query
        Write-Verbose ("Fetching inventory for object type " + $objectType)

        try {
            $vrObjs = Invoke-RestMethod -Method Get -Uri ("https://" + $vROpsCon.vropsnode + "/suite-api/api/resources?adapterKind=" + $adapterType + "&resourceKind=" + $objectType + "&pageSize=1000") -Headers $headers -SkipCertificateCheck:$vROPSCon.skipCertificates -ErrorAction Stop
            Write-Verbose ("Query successful.")
        } # try
        catch {
            throw ("Failed to query vROPs node. " + $_.exception.message)
        } # catch


        ## Apply pagination if required
        $resourceList = @()

        ## Add the initial result set so we don't need to query the first page again
        $resourceList += $vrObjs.resourceList

        ## Figure out how many pages
        if ($vrObjs.pageInfo.totalCount -gt $vrObjs.pageInfo.pageSize) {

            Write-Verbose ([string]$vrObjs.pageInfo.totalCount + " objects found. Pagination required.")

            ## Figure out how many pages. Round down to nearest whole number as pages start at 0
            $pageCount = [math]::floor(($vrObjs.pageInfo.totalCount / $vrObjs.pageInfo.pageSize))

            Write-Verbose ([string]$pageCount + " pages required.")

            ## Start from page 1 rather than 0 as we already have the first page
            for($pageNum=1; $pageNum -le $pageCount; $pageNum++){

                ## Build request string for this page
                Write-Verbose ("Querying page at https://" + $vROpsCon.vropsnode + "/suite-api/api/resources?adapterKind=" + $adapterType + "&resourceKind=" + $objectType + "&pageSize=1000&page=" + $pageNum)

                $resourceList += (Invoke-RestMethod -Method Get -Uri ("https://" + $vROpsCon.vropsnode + "/suite-api/api/resources?adapterKind=" + $adapterType + "&resourceKind=" + $objectType + "&pageSize=1000&page=" + $pageNum) -Headers $headers -SkipCertificateCheck:$vROPSCon.skipCertificates).resourceList

            } # for

        } # if


        ## Set process script block. We add source vrops and object type properties to output
        $feProcess = {
            $_ | Add-Member -MemberType NoteProperty -Name "vrops" -Value $vROpsCon.vropsnode -PassThru | Add-Member -MemberType NoteProperty -Name "objectType" -Value $objectType -PassThru
        } # feProcess


        ## Sort list for return
        $sortedObjs = $resourceList | Select-Object Identifier, @{label='name'; expression={$_.resourceKey.name}} | ForEach-Object -Process $feProcess

        return $sortedObjs


        Write-Verbose ("Completed node.")

    } # process

    end {

        Write-Verbose ("Function complete.")
    } # end


} # function
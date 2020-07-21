function Get-vROPsInventory {
    <#
    .SYNOPSIS
        Return a list of objects managed by the specified vrops instance.

    .DESCRIPTION
        Return a list of objects managed by the specified vrops instance.
        Object type requires to be spcified, i.e. host, virtual machine etc.
        Only objects collected by adapter type VMWARE are returned.

    .PARAMETER vROPSCon
        A vROPs connection object as created by Connect-vROPs

    .PARAMETER ObjectType
        The specified object type to query for.

    .PARAMETER ObjectType
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
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [vropsConnection]$vROpsCon,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("virtualMachine","hostSystem")]
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
            $vrObjs = Invoke-RestMethod -Method Get -Uri ("https://" + $vROpsCon.vropsnode + "/suite-api/api/resources?adapterKind=" + $adapterType + "&resourceKind=" + $objectType + "&pageSize=10000") -Headers $headers -ErrorAction Stop
            Write-Verbose ("Query successful.")
        } # try
        catch {
            Write-Debug ("Connection failed.")
            throw ("Failed to query vROPs node. " + $_.exception.message)
        } # catch


        ## Set process script block. We add source vrops and object type properties to output
        $feProcess = {
            $_ | Add-Member -MemberType NoteProperty -Name "vrops" -Value $vROpsCon.vropsnode -PassThru | Add-Member -MemberType NoteProperty -Name "objectType" -Value $objectType -PassThru
        } # feProcess


        ## Sort list for return
        $sortedObjs = $vrObjs.resourceList.resourceKey | Select-Object Name -Unique | Sort-Object Name | ForEach-Object -Process $feProcess

        return $sortedObjs


        Write-Verbose ("Completed node.")

    } # process

    end {

        Write-Verbose ("Function complete.")
    } # end


} # function
function Deploy-vROPS {
    <#
    .SYNOPSIS
        Deploy a vRealize Operations Manager instance from OVA file.

    .DESCRIPTION
        Deploy a vRealize Operations Manager instance from OVA file.

        Suitable for 8.x appliances.

    .PARAMETER ovaPath
        The path to the vRops OVA file to deploy.

    .PARAMETER vmName
        The name of the VM object to create.

    .PARAMETER vmHost
        The ESXi host to deploy to.

    .PARAMETER datastore
        The datastore to deploy to (must be available on the target ESXi host).

    .PARAMETER ip
        The IP address to assign to the appliance.

    .PARAMETER netmask
        The subnet mask to assign to the appliance.

    .PARAMETER gateway
        The default gateway to assign to the appliance.

    .PARAMETER dns
        The DNS server to assign to the appliance.

    .PARAMETER network
        The name of the portgroup to attach the appliance to.

    .PARAMETER domain
        The domain name of the appliance. Blank for DHCP.

    .PARAMETER size
        The appliance size to deploy.

    .INPUTS
        None.

    .OUTPUTS
        VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl

    .EXAMPLE
        Deploy-vROPS -ovaPath D:\dml\vRealize-Operations-Manager-Appliance-8.6.1.18985958_OVF10.ova -vmName podvr01 -vmHost podesx04.pod.local -datastore custVsan `
        -ip 10.10.1.102 -netmask 255.255.255.0 -gateway 10.10.1.1 -dns 10.10.1.20 -network pg-mgmt -domain pod.local -size small

        Deploy a small appliance from the specified OVA with the specified configuration.

    .LINK

    .NOTES

    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$ovaPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$vmName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$vmHost,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$datastore,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$ip,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$netmask,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$gateway,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$dns,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$network,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [string]$domain,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("small", "medium", "large", "smallrc", "largerc", "witness", "xsmall", "xlarge")]
        [string]$size
    )

    begin {
        Write-Verbose ("Function start.")

    } # begin


    process {

        Write-Verbose ("Processing deplyoment " + $ovaPath)

        Write-Verbose ("Setting OVA deployment options.")
        try {
            $vropsConfig = Get-OvfConfiguration -Ovf $ovaPath -ErrorAction Stop
            $vropsConfig.vami.vRealize_Operations_Appliance.ip0.value = $ip
            $vropsConfig.vami.vRealize_Operations_Appliance.netmask0.value = $netmask
            $vropsConfig.vami.vRealize_Operations_Appliance.gateway.value = $gateway
            $vropsConfig.vami.vRealize_Operations_Appliance.DNS.value = $dns
            $vropsConfig.vami.vRealize_Operations_Appliance.domain.value = $domain
            $vropsConfig.vami.vRealize_Operations_Appliance.searchpath.value = $searchPath
            $vropsConfig.Common.forceIpv6.Value = $false
            $vropsConfig.Common.vamitimezone.value = "Etc/UTC"
            $vropsConfig.DeploymentOption.value = $size
            $vropsConfig.NetworkMapping.Network_1.Value = $network
            $vropsConfig.IpAssignment.IpProtocol.Value = "IPv4"

            Write-Verbose ("Deployment options have been set.")
        } # try
        catch {
            throw ("Failed to set deployment options. Verify OVA file and version. " + $_.exception.Message)
        } # catch


        ## Deploy the appliance
        Write-Verbose ("Invoking appliance deployment.")

        try {
            $vm = Import-VApp -Source $ovaPath -OvfConfiguration $vropsConfig -Name $vmName -Datastore $datastore -DiskStorageFormat thin -VMHost $vmHost -ErrorAction Stop
            Write-Verbose ("Appliance has been deployed.")
        } # try
        catch {
            throw ("Failed to deploy appliance. " + $_.exception.message)
        } # catch


        ## Power up appliance and wait for tools
        Write-Verbose ("Starting VM and waiting for VM tools.")

        try {
            Start-VM -VM $vm -ErrorAction Stop | Wait-Tools | Out-Null
            Write-Verbose ("VM has started and tools is available.")
        } # try
        catch {
            throw ("Failed to power on appliance. " + $_.Exception.Message)
        } # catch

        Write-Verbose ("Deployment complete.")

        ## Return VM object
        return $vm

    } # process

    end {
        Write-Verbose ("Function complete.")

    } # end

} # function
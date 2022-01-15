function Get-NodeThumbprint {
    <#
    .SYNOPSIS
        Get the SSL thumbprint of a node.

    .DESCRIPTION
        Get the SSL thumbprint of a node.
        Can be returned with optional formatting.

    .PARAMETER targetNode
        Target node to get thumbprint from.

    .PARAMETER thumbprintFormat
        Format of the thumbprint string to return.

    .INPUTS
        System.String

    .OUTPUTS
        System.String

    .EXAMPLE
        Get-NodeThumbprint -targetNode vcsa.lab.local -thumbprintFormat colon

        Return the certificate thumbprint of vcsa.lab.local in colon notation.

    .LINK

    .NOTES

    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$targetNode,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("none", "colon")]
        [string]$thumbprintFormat
    )

    begin {
        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Getting thumbprint for " + $targetNode)

        ## Create a TCP socket to target node
        try {
            $tcpSocket = New-Object Net.Sockets.TcpClient($targetNode, "443")
        } # try
        catch {
            throw ("Failed to open TCP stream to target node. " + $_.Exception.Message)
        } # catch


        ## Create TCP stream to target node
        $tcpStream = $tcpSocket.GetStream()


        ## Specify what protcols are supported, in this case TLS 1.2
        $sslProtocols = New-Object System.Security.Authentication.SslProtocols
        $sslProtocols = "Tls12"


        ## Get certificate from appliance. This SSL constructor allows for self signed certs
        $sslStream = New-Object System.Net.Security.SslStream($tcpStream,$false, {
            param($sender, $certificate, $chain, $sslPolicyErrors)
            return $true
            })


        ## Force the SSL Connection to send us the certificate
        try {
            $sslStream.AuthenticateAsClient($targetNode, $null, $sslProtocols, $true);
        } # try
        catch {
            throw ("Failed to open TCP stream to target node. " + $_.Exception.Message)
        } # catch


        ## Get certificate thumbprint
        $thumbPrint = (New-Object system.security.cryptography.x509certificates.x509certificate2($sslStream.RemoteCertificate)).Thumbprint


        ## Switch on format option
        switch ($thumbprintFormat) {

            ## No formatting required, return as is
            "none" {
                ## We don't need to do anything
                Break
            } # none

            "colon" {

                for ($i = 2 ; $i -le 57 ; $i += 3) {
                    $thumbPrint = $thumbPrint.insert($i,":")
                } # for
                Break
            } # colon

        } # switch

        Write-Verbose ("Completed node.")

        return $thumbPrint

    } # process

    end {
        Write-Verbose ("Function completed.")

    } # end

} # function
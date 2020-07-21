function Connect-vROPs {
    <#
    .SYNOPSIS
        Create a connection object to a vRealize Operations Manager appliance.

    .DESCRIPTION
        Create a connection object to a vRealize Operations Manager appliance.
        Acquires a token from the appliance REST API.

    .PARAMETER vROPSNode
        The target vROPs node to connect to.

    .PARAMETER Credential
        The credentials used to connect.

    .INPUTS
        System.String. Target vRops node.

    .OUTPUTS
        None.

    .EXAMPLE
        $token = Connect-vROPs -vROPSNode vrops01.lab.local -Credential $creds

        Return a connection token from vrops01 using $creds

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
        $headers.Add("Content-Type", "application/json")

        ## Capture account details. If @ is specified, split this and use as authSource
        $authSource = $Credential.UserName.Split("@")[1]
        $userName = $Credential.UserName.Split("@")[0]


        ## If not, we assume local account
        if (!$authSource) {
            $authSource = "LOCAL"
        } # if


        ## Set body content
        $bodyObj = [pscustomobject]@{
            "username" = $userName;
            "authSource" = $authSource;
            "password" = $Credential.GetNetworkCredential().Password;
            "others" = "[]";
            "otherAttributes" = "{}"
        }


    } # begin


    process {

        Write-Verbose ("Processing vROPs node " + $vROPSNode)


        ## Conenct to vRops node
        Write-Verbose ("Attempting connection.")

        try {
            $authToken = Invoke-RestMethod -Method Post -Uri ("https://" + $vROPSNode + "/suite-api/api/auth/token/acquire") -Body ($bodyObj | ConvertTo-Json) -Headers $headers -ErrorAction Stop
            Write-Verbose ("Connection successful.")
        } # try
        catch {
            Write-Debug ("Connection failed.")
            throw ("Failed to connect to vROPs node. " + $_.exception.message)
        } # catch


        ## Return completed object using vropsConnection class
        return [vropsConnection]::new($vROPsNode, $Credential.UserName, $authToken.token, $authToken.expiresat, (Get-Date))


    } # process


    end {

        Write-Verbose ("Function complete.")

    } # end

} # function
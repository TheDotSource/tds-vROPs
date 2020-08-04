function Connect-vROPs {
    <#
    .SYNOPSIS
        Create a connection object to a vRealize Operations Manager appliance.

    .DESCRIPTION
        Create a connection object to a vRealize Operations Manager appliance.
        Acquires a token from the appliance REST API.

        If a flat username is specified, e.g. "testuser", then the authentication source is assumed to be local.

        If a fully qualified username is specified, e.g. "testuser@domain.local", then the authentication source is assumed to be domain.local.

        Either of the above can be overriden by using the optional authSource parameter (see examples).

    .PARAMETER vROPSNode
        The target vROPs node to connect to.

    .PARAMETER Credential
        The credentials used to connect.

    .PARAMETER authSource
        Optional. Manually specified authentication source.

    .INPUTS
        System.String. Target vRops node.

    .OUTPUTS
        None.

    .EXAMPLE
        $token = Connect-vROPs -vROPSNode vrops01.lab.local -Credential $creds

        Return a connection token from vrops01 using $creds

    .EXAMPLE
        $token = Connect-vROPs -vROPSNode vrops01.lab.local -Credential $creds -authSource lab.local

        Return a connection token from vrops01 using $creds, authenticate using lab.local as the authentication source.

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
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$false,ValueFromPipeline=$true)]
        [string]$authSource
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


        ## Check if authSource is specified
        if ($authSource) {

            Write-Verbose ($authSource + " has been specified as the authentication source.")

        } # if
        else {

            Write-Verbose ("Authentication source was not specified, it will be derived.")

            ## Capture account details. If @ is specified, split this and use as authSource
            $authSource = $Credential.UserName.Split("@")[1]

            ## If not, we assume local account
            if (!$authSource) {
                $authSource = "LOCAL"
            } # if

        } # else

        Write-Verbose ("Authentication source is " + $authSource)

        ## Set body content
        $bodyObj = [pscustomobject]@{
            "username" =   $Credential.UserName.Split("@")[0];
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


        ## Set headers for API request for version data
        $headers.Add("Authorization", ("vRealizeOpsToken " + $authToken.'auth-token'.token))

        Write-Verbose ("Fetching node version data.")


        ## Fetch version data. This would normally be done via /suite-api/api/versions/current. However in 7.5 this request hangs.
        ## We determine the version by querying /versions and taking the latest
        try {
            $versionData = (Invoke-RestMethod -Method Get -Uri ("https://" + $vROPSNode + "/suite-api/api/versions") -Headers $headers -ErrorAction Stop).values | Sort-Object -Property releaseName -Descending | Select-Object releaseName -First 1
            Write-Verbose ("Got version data.")
        } # try
        catch {
            Write-Debug ("Failed to get version data.")
            throw ("Failed to get version data. " + $_.exception.message)
        } # catch


        ## Return completed object using vropsConnection class
        return [vropsConnection]::new($vROPsNode, $Credential.UserName, $authToken.token, $authToken.expiresat, $versionData.releaseName, (Get-Date))


    } # process


    end {

        Write-Verbose ("Function complete.")

    } # end

} # function
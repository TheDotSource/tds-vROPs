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

    .PARAMETER skipCertificates
        Ignore invalid or self signed certificates.

    .INPUTS
        System.String. Target vRops node.

    .OUTPUTS
        vropsConnection. vRops connection object.

    .EXAMPLE
        $token = Connect-vROPs -vROPSNode vrops01.lab.local -Credential $creds

        Return a connection token from vrops01 using $creds

    .EXAMPLE
        $token = Connect-vROPs -vROPSNode vrops01.lab.local -Credential $creds -skipCertificates

        Return a connection token from vrops01 using $creds, ignore self signed certificates.

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
        [string]$authSource,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [switch]$skipCertificates = $false
    )

    begin {

        Write-Verbose ("Starting function.")

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
            $authToken = Invoke-RestMethod -Method Post -Uri ("https://" + $vROPSNode + "/suite-api/api/auth/token/acquire") -Body ($bodyObj | ConvertTo-Json) -Headers $headers -SkipCertificateCheck:$skipCertificates -ErrorAction Stop
            Write-Verbose ("Connection successful.")
        } # try
        catch {
            Write-Debug ("Connection failed.")
            throw ("Failed to connect to vROPs node. " + $_.exception.message)
        } # catch


        ## Return completed object using vropsConnection class
        return [vropsConnection]::new($vROPsNode, $Credential.UserName, $authToken.token, $authToken.expiresat, (Get-Date), $skipCertificates)


    } # process


    end {

        Write-Verbose ("Function complete.")

    } # end

} # function
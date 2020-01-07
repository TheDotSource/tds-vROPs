function Export-VROPsPolicy {
    <#
    .SYNOPSIS
        Export a policy from vROPs and save to XML.

    .DESCRIPTION
        Taking the policy name as input, the function does the following:
            * Performs a lookup to get the associated GUID
            * Downloads the zip archive of the policy from API
            * Extracts the XML string and saves it to the specified directory using the naming format <vrops node>-<policy name>.xml

    .PARAMETER vROPSNode
        The target vROPs node to perform an export on. Can be pipelined.

    .PARAMETER destinationDir
        The destination directory to save the XML file.

    .PARAMETER policyName
        The vROPs policy name to fetch content for.

    .PARAMETER Credential
        PowerShell credential object with appropriate permissions for policy export.

    .INPUTS
        System.String. vROPs node names can be piped to this function.

    .OUTPUTS
        None.

    .EXAMPLE
        "testvro01.lab.local","testvro02.lab.local" | Export-VROPsPolicy -destinationDir C:\vROPsDemo -Credential $creds -policyName TEST-POLICY02 -Verbose

        Export TEST-POLICY02 from testvro01.lab.local and testvro02.lab.local, save them to c:\vROPsDemo as testvro01.lab.local-TEST-POLICY2.xml and testvro02.lab.local-TEST-POLICY2.xml respectively.
        Use the credential object $creds and use verbose output.

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
        [String]$destinationDir,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$policyName,
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
        $headers.Add("Content-Type", "application/xml;charset=utf-8")

        ## Add unsupported header as some calls go to internal API
        $headers.Add("X-vRealizeOps-API-use-unsupported", "true")


        ## Load the required assemblies for handling zip files
        Write-Verbose ("Loading assemblies.")

        try {
            Add-Type -Assembly System.IO.Compression -ErrorAction Stop | Out-Null
        } # try
        catch {
            Write-Debug ("Failed to load assemblies.")
            throw ("Failed to load assemblies, the CMDlet returned " + $_.exception.message)
        } # catch

        Write-Verbose ("Assemblies were loaded.")


        ## Test desintation directory
        if (!(Test-Path -Path $destinationDir)) {
            throw ("Specified desintation path was not found.")
        } # if

        ## Trim any trailing \ from path
        $destinationDir = $destinationDir.trim("\")

        Write-Verbose ("Output directory will be " + $destinationDir)


    } # begin

    process {

        Write-Verbose ("Processing vROPS node " + $vROPSNode)


        ## Set target URL for requesting policy list
        $Uri = ("https://" + $vROPSNode + "/suite-api/internal/policies")
        Write-Verbose ("Fetching policies.")


        ## Get policies from this vROPs node
        try {
            $vropsPolicies = Invoke-RestMethod -Uri $Uri -Method Get -Headers $headers -Credential $Credential -ErrorAction Stop
            Write-Verbose ("Got list of policies and GUIDs from API.")
        } # try
        catch {
            Write-Debug ("Failed to get policies.")
            throw ("Failed to get policies, the CMDlet returned " + $_.exception.message)
        } # catch


        ## Get policy ID for the specified name
        $policyGUID = $vropsPolicies.'policy-summaries' | Where-Object {$_.name -eq $policyName}


        ## Check we have 1 policy to work with
        if (($policyGUID | Measure-Object).count -ne 1) {
            throw ("The specified policy was not found on this vROPs instance.")
        } # if


        Write-Verbose ("Found GUID for policy  " + $policyName)


        ## Fetch this policy from API, API returns in zip format
        $Uri = ("https://" + $vROPSNode + "/suite-api/internal/policies/export?id=" + $policyGUID.id)

        Write-Verbose ("Fetching policy zip")

        try {
            $policyZip = Invoke-WebRequest -Uri $Uri -Method Get -Headers $headers -Credential $Credential -ErrorAction Stop
            Write-Verbose ("Fetched policy zip from API.")
        } # try
        catch {
            Write-Debug ("Failed to get policy zip.")
            throw ("Failed to get policy zip, the CMDlet returned " + $_.exception.message)
        } # catch


        Write-Verbose ("Decompressing zip and reading policy XML.")


        ## We need to open this zip and extract the resulting XML so we can parse it later
        try {
            $apiZip = New-Object System.IO.Memorystream -ErrorAction Stop
            $apiZip.Write($policyZip.Content,0,$policyZip.Content.Length)
            $zipArchive = New-Object System.IO.Compression.ZipArchive($apiZip) -ErrorAction Stop
            $zipEntry = $zipArchive.GetEntry('exportedPolicies.xml')
            $entryReader = New-Object System.IO.StreamReader($zipEntry.Open()) -ErrorAction Stop
            $policyXML = $EntryReader.ReadToEnd()
        } # try
        catch {
            Write-Debug ("Failed to open policy zip file.")
            throw ("Failed to open policy zip file, the CMDlet returned " + $_.exception.message)
        } # catch


        ## Configure UTF-8 without BOM encoding. Otherwise API rejects the content on import
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false


        ## Write out this XML file
        try {
            [System.IO.File]::WriteAllLines(($destinationDir + "\" + $vROPSNode + "-" + $policyName + ".xml"), $policyXML, $Utf8NoBomEncoding)
            Write-Verbose ("Created policy file " + ($destinationDir + "\" + $vROPSNode + "-" + $policyName + ".xml"))
        } # try
        catch {
            Write-Debug ("Failed to write policy file.")
            throw ("Failed to write policy file, the CMDlet returned " + $_.exception.message)
        } # catch


    } # process


    end {

        Write-Verbose ("Function complete.")

    } # end


} # function
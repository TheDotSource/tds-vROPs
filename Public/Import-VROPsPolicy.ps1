﻿function Import-VROPsPolicy {
    <#
    .SYNOPSIS
        Imports and XML policy to a vROPs node.

    .DESCRIPTION
        This function will take a previously exported vROPs policy and import it to the target node(s)
        The function will compress the XML in memory and inject it to the HTTP body.
        The function can optionally overwrite any existing policy.

    .PARAMETER vROPSNode
        The target vROPs node to perform an import on. Can be pipelined.

    .PARAMETER policyFile
        The XML policy file to import, which was exported from the same or another vROPs node.

    .PARAMETER forceUpdate
        Optional parameter. Will overwrite an existing policy with the new one.

    .PARAMETER Credential
        PowerShell credential object with appropriate permissions for policy import.

    .INPUTS
        System.String. vROPs node names can be piped to this function.

    .OUTPUTS
        None.

    .EXAMPLE
        Import-VROPsPolicy -vROPSNode vrops01.lab.local -policyFile c:\policies\sample.xml -forceUpdate -Credential $creds -Verbose

        Import the policy file sample.xml to the vROPs node vrops.lab.local and force overwrite. Uses credential object $creds and specifies verbose output

    .EXAMPLE
        $vROPSNodes | Import-VROPsPolicy -policyFile c:\policies\sample.xml -forceUpdate -Credential $creds

        Import the policy file sample.xml to all vROPs nodes within the $vROPSNodes array and force overwrite. Uses credential object $creds.

    .EXAMPLE
        $vROPSNodes | Import-VROPsPolicy -policyFile c:\policies\sample.xml -Credential $creds

        Import the policy file sample.xml to all vROPs nodes within the $vROPSNodes array (will not overwrite). Uses credential object $creds.

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
        [String]$policyFile,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [Switch]$forceUpdate
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

        ## Validate specified policy file
        if (!(Test-Path $policyFile)) {

            throw ("Specified policy file " + $policyFile + " was not found.")
        } # if

        Write-Verbose ("Using policy file " + $policyFile)


        if ($forceUpdate.IsPresent) {
            Write-Verbose ("Policy overwrite has been specified.")
        } # if


        ## Create an HTTP boundary, required for multipart uploads
        $httpBoundary = [guid]::NewGuid().ToString()

        ## Define headers
        $headers = @{}
        $headers.Add("Content-Type", 'multipart/mixed')
        $headers.Add("Accept", 'application/json')
        $headers.Add("X-vRealizeOps-API-use-unsupported", 'true')

    } # begin


    process {


        Write-Verbose ("Processing vROPS node " + $vROPSNode)


        ## Read file out to binary
        $policyBin = [System.IO.File]::ReadAllBytes($policyFile)

        ## Load the required assemblies
        try {
            Add-Type -Assembly System.IO.Compression -ErrorAction Stop | Out-Null
        } # try
        catch {
            Write-Debug ("Failed to load assemblies.")
            throw ("Failed to load assemblies, the CMDlet returned " + $_.exception.message)
        } # catch

        ## Set encoding scheme
        $encodingScheme = [System.Text.Encoding]::GetEncoding("iso-8859-1")

        ## Declare new memory stream
        [System.IO.MemoryStream] $memStream = New-Object System.IO.MemoryStream

        Write-Verbose ("Compressing policy file.")

        ## Declare new zip archive and set compression mode
        $zipArchive = [System.IO.Compression.ZipArchive]::new($memStream, ([IO.Compression.CompressionMode]::Compress))

        ## Set new entry in this zip for policy file
        $zipEntry = $zipArchive.CreateEntry("policyImport.xml")

        ## Open stream to this file and write in contents
        $fileStream = $zipEntry.Open()
        $fileStream.Write($policyBin, 0, $policyBin.Length)

        ## Close the file steam
        $fileStream.Close()

        ## Close the memoroy stream
        $memStream.Close()

        ## Output byte array
        $finalZip = $memStream.ToArray()

        ## Configure a here string with HTTP header content
	    $httpTemplate = @"
--{0}
Content-Disposition: form-data; name=forceImport

{1}
--{0}
Content-Disposition: form-data; name=policy; filename=policyImport.zip
Content-Type: multipart/form-data

{2}
--{0}--
"@


        ## Inject content
        try {
            $httpBody = $httpTemplate -f $httpBoundary, $forceUpdate.IsPresent, $encodingScheme.GetString($finalZip)
            Write-Verbose ("HTTP request template configured.")
        } # try
        catch {
            Write-Debug ("Failed to set HTTP request.")
            throw ("Failed to configure HTTP request, the CMDlet returned " + $_.exception.message)
        } # catch

        ## Set target URI for this node
        $Uri = ("https://" + $vROPSNode + "/suite-api/internal/policies/import")


        ## Send request to import
        try {
            $policyImport = Invoke-RestMethod -Uri $Uri -Method Post -ContentType "multipart/form-data; boundary=$httpBoundary;" -Body $httpBody -Headers $headers -Credential $Credential -ErrorAction Stop
            Write-Verbose ("Policy import was successful")
        } # try
        catch {
            Write-Debug ("Failed to import policy file.")
            throw ("Failed to import policy file, the CMDlet returned " + $_.exception.message)
        } # catch


        ## The API always returns a 202 success code, even if import failed. We can't use this to indicate success.
        ## We need to check that at least 1 policy was created, updated or skipped. If all conditions are 0 then the import failed.
        if (($policyImport.'created-policies'.count -eq 0) -and ($policyImport.'skipped-policies'.count -eq 0) -and ($policyImport.'updated-policies'.count -eq 0)) {
            throw ("Policy import failed. Check that the XML is valid and the character encoding is UTF-8 without BOM.")
        } # if
        else {
            Write-Verbose ("Policy created count: " + $policyImport.'created-policies'.count)
            Write-Verbose ("Policy updated count: " + $policyImport.'updated-policies'.count)
            Write-Verbose ("Policy skipped count: " + $policyImport.'skipped-policies'.count)
        } # else


        Write-Verbose ("vROPS node complete.")

    } # process


    end {
        Write-Verbose ("Function complete.")
    } # end


} # function
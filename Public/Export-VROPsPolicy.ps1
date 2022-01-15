function Export-VROPsPolicy {
    <#
    .SYNOPSIS
        Export a policy from vROPs and save to XML.

    .DESCRIPTION
        Taking the policy name as input, the function does the following:
            * Performs a lookup to get the associated GUID
            * Downloads the zip archive of the policy from API
            * Extracts the XML string and saves it to the specified directory using the naming format <vrops node>-<policy name>.xml

    .PARAMETER vROPSCon
        A vROPs connection object as created by Connect-vROPs

    .PARAMETER destinationDir
        The destination directory to save the XML file.

    .PARAMETER policyName
        The vROPs policy name to fetch content for.

    .INPUTS
        vropsConnection. A vROPs connection object.

    .OUTPUTS
        None.

    .EXAMPLE
        Export-VROPsPolicy -vROPSCon $vRopsCon -destinationDir C:\vROPsDemo -policyName TEST-POLICY02

        Export TEST-POLICY02 and save to c:\vROPsDemo. Use the vrops connection object $vRopsCon

    .LINK

    .NOTES

    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [vropsConnection]$vROPSCon,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$destinationDir,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$policyName
    )

    begin {

        Write-Verbose ("Starting function.")


        ## Load the required assemblies for handling zip files
        Write-Verbose ("Loading assemblies.")

        try {
            Add-Type -Assembly System.IO.Compression -ErrorAction Stop | Out-Null
            Write-Verbose ("Assemblies loaded.")
        } # try
        catch {
            throw ("Failed to load assemblies, the CMDlet returned " + $_.exception.message)
        } # catch


        ## Test desintation directory
        if (!(Test-Path -Path $destinationDir)) {
            throw ("Specified desintation path was not found.")
        } # if

        ## Trim any trailing \ from path
        $destinationDir = $destinationDir.trim("\")

        Write-Verbose ("Output directory is " + $destinationDir)


    } # begin

    process {

        Write-Verbose ("Processing vROPS node " + $vROPSNode)

        ## Define headers for HTTP requests
        $headers = @{}
        $headers.Add("Accept", "application/zip, application/json")
        $headers.Add("Content-Type", "application/json")
        $headers.Add("Authorization", ("vRealizeOpsToken " + $vROpsCon.authToken))

        ## Add unsupported header as some calls go to internal API
        $headers.Add("X-vRealizeOps-API-use-unsupported", "true")


        ## Set target URL for requesting policy list
        $Uri = ("https://" + $vROPSCon.vROPSNode + "/suite-api/internal/policies")
        Write-Verbose ("Fetching policies.")


        ## Get policies from this vROPs node
        try {
            $vropsPolicies = Invoke-RestMethod -Uri $Uri -Method Get -Headers $headers -SkipCertificateCheck:$vROPSCon.skipCertificates -ErrorAction Stop
            Write-Verbose ("Got list of policies and GUIDs from API.")
        } # try
        catch {
            throw ("Failed to get policies, the CMDlet returned " + $_.exception.message)
        } # catch


        ## Get policy ID for the specified name
        $policyGUID = $vropsPolicies.'policy-summaries' | Where-Object {$_.name -eq $policyName}


        ## Check we have 1 policy to work with
        if (($policyGUID | Measure-Object).count -ne 1) {
            throw ("The specified policy was not found on this vROPs instance.")
        } # if


        Write-Verbose ("Found GUID for policy " + $policyName + " (" + $policyGUID.id + ")")

        ## Fetch this policy from API, API returns in zip format
        $Uri = ("https://" + $vROPSCon.vROPSNode + "/suite-api/internal/policies/export?id=" + $policyGUID.id)

        Write-Verbose ("Fetching policy zip")

        try {
            $policyZip = Invoke-WebRequest -Uri $Uri -Method Get -Headers $headers -SkipCertificateCheck:$vROPSCon.skipCertificates -ErrorAction Stop
            Write-Verbose ("Fetched policy zip from API.")
        } # try
        catch {
            throw ("Failed to get policy zip, the CMDlet returned " + $_.exception.message)
        } # catch


        Write-Verbose ("Decompressing zip and reading policy XML.")


        ## We need to open this zip and extract the resulting XML
        try {
            $apiZip = New-Object System.IO.Memorystream -ErrorAction Stop
            $apiZip.Write($policyZip.Content,0,$policyZip.Content.Length)
            $zipArchive = New-Object System.IO.Compression.ZipArchive($apiZip) -ErrorAction Stop
            $zipEntry = $zipArchive.GetEntry('exportedPolicies.xml')
            $entryReader = New-Object System.IO.StreamReader($zipEntry.Open()) -ErrorAction Stop
            $policyXML = $EntryReader.ReadToEnd()
        } # try
        catch {
            throw ("Failed to open policy zip file. Verify that the account used is a member of the vRops system administrators, otherwise policy export is not possible. The CMDlet returned " + $_.exception.message)
        } # catch


        ## Configure UTF-8 without BOM encoding. Otherwise API rejects the content on import
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $false


        ## Write out this XML file
        try {
            [System.IO.File]::WriteAllLines(($destinationDir + "\" + $vROPSCon.vROPSNode + "-" + $policyName + ".xml"), $policyXML, $Utf8NoBomEncoding)
            Write-Verbose ("Created policy file " + ($destinationDir + "\" + $vROPSCon.vROPSNode + "-" + $policyName + ".xml"))
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
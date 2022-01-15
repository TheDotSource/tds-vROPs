function Get-vROPsPolicyReport {
    <#
    .SYNOPSIS
        Outputs a report on what alerts are associated with what policies.

    .DESCRIPTION
        This function will collect all alerts from the vROPs API.
        It will then get a list of all policy objects, iterate through these and determine what alerts are used in what policies.
        The function will return a collection of alert objects with an associated collection of policies.

    .PARAMETER vROPSCon
        A vROPs connection object as created by Connect-vROPs

    .INPUTS
        vropsConnection. A vROPs connection object.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. A collection of custom objects representing alerts and their associated policies.

    .EXAMPLE
        $results = Get-vROPsPolicyReport -vROPSCon $vRopsCon

        Query on $vRopsCon and save results to $results.

    .LINK

    .NOTES

    #>

    [OutputType("System.Collections.ArrayList")]
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [vropsConnection]$vROPSCon
    )

    begin {

        Write-Verbose ("Starting function.")

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


    } # begin


    process {

        Write-Verbose ("Processing vROPS node " + $vROPSCon.vROPSNode)

        ## Define headers for HTTP requests
        $headers = @{}
        $headers.Add("Accept", "application/zip, application/json")
        $headers.Add("Content-Type", "application/xml;charset=utf-8")
        $headers.Add("Authorization", ("vRealizeOpsToken " + $vROpsCon.authToken))

        ## Add unsupported header as some calls go to internal API
        $headers.Add("X-vRealizeOps-API-use-unsupported", "true")


        ## Initiliase array for alert objects (.net array used for better performance)
        $alertObjs = [System.Collections.ArrayList]@()

        ## Set target URI for this node
        $Uri = ("https://" + $vROPSCon.vROPSNode + "/suite-api/api/alertdefinitions")


        ## Get all alert content
        try {
            $vropsAlerts = Invoke-RestMethod -Uri $Uri -Method Get -Headers $headers -SkipCertificateCheck:$vROPSCon.skipCertificates -ErrorAction Stop
            Write-Verbose ("Got alerts from API.")
        } # try
        catch {
            throw ("Failed to get alerts, the CMDlet returned " + $_.exception.message)
        } # catch


        ## Iterate through alerts and create objects for each
        foreach ($vropsAlert in $vropsAlerts.alertDefinitions) {

            $alertObjs.Add([pscustomobject]@{"vropsInstance" = $vROPSCon.vROPSNode;"alertName" = $vropsAlert.name; "alertId" = $vropsAlert.id; "alertPolicies" = @()}) | Out-Null

        } # foreach

        Write-Verbose ("Collected policy names and IDs.")


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


        ## Iterate through each policy, decompress and get alert associations, excluding the Base Settings policy
        foreach ($vropsPolicy in $vropsPolicies.'policy-summaries'  | Where-Object {$_.name -ne "Base Settings"}) {

            Write-Verbose ("Processing vROPs policy " + $vropsPolicy.name)


            ## Fetch this policy from API, API returns in zip format
            $Uri = ("https://" + $vROPSCon.vROPSNode + "/suite-api/internal/policies/export?id=" + $vropsPolicy.id)

            try {
                $vropsPolicies = Invoke-WebRequest -Uri $Uri -Method Get -Headers $headers -SkipCertificateCheck:$vROPSCon.skipCertificates -ErrorAction Stop
                Write-Verbose ("Fetched policy zip from API.")
            } # try
            catch {
                throw ("Failed to get policy zip, the CMDlet returned " + $_.exception.message)
            } # catch


            Write-Verbose ("Decompressing zip and reading policy XML.")


            ## We need to open this zip and extract the resulting XML so we can parse it later
            try {
                $apiZip = New-Object System.IO.Memorystream -ErrorAction Stop
                $apiZip.Write($vropsPolicies.Content,0,$vropsPolicies.Content.Length)
                $zipArchive = New-Object System.IO.Compression.ZipArchive($apiZip) -ErrorAction Stop
                $ZipEntry = $zipArchive.GetEntry('exportedPolicies.xml')
                $entryReader = New-Object System.IO.StreamReader($ZipEntry.Open()) -ErrorAction Stop

                ## Cast variable to type xml and read contents from zip
                [xml]$policyXML = $EntryReader.ReadToEnd()
            } # try
            catch {
                throw ("Failed to open policy zip file, the CMDlet returned " + $_.exception.message)
            } # catch


            Write-Verbose ("Got policy XML.")


            ## Check that this policy has alerts explicitly defined, otherwise we don't need to do any further processing and can continue to next iteration
            if (($policyXML.PolicyContent.Policies.SelectNodes(("//Policy[@name=`"" + $vropsPolicy.name + "`"]")).PackageSettings.Alerts | Measure-Object).count -lt 1) {
                Write-Verbose ("No alerts locally defined within this policy, no further processing necessary.")
                Continue
            } # if


            ## Iterate through each alert and check if it is associated with this policy
            foreach ($alertObj in $alertObjs) {

                if ($policyXML.PolicyContent.Policies.SelectNodes(("//Policy[@name=`"" + $vropsPolicy.name + "`"]")).PackageSettings.Alerts.SelectNodes(("//Alert[@id='" + $alertObj.alertId + "']")).enabled) {

                    Write-Verbose ($alertObj.alertName + " is associated with policy " + $vropsPolicy.name)
                    $alertObj.alertPolicies += $vropsPolicy.name

                } # if

            } # foreach


        } # foreach


        Write-Verbose ("Returning object.")

        return $alertObjs

    } # process


    end {

        Write-Verbose ("Function complete.")

    } # end

} # function
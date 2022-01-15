$public = @(Get-ChildItem -Path "$($PSScriptRoot)/public/*.ps1" -ErrorAction "SilentlyContinue")
$private = @(Get-ChildItem -Path "$($PSScriptRoot)/private/*.ps1" -ErrorAction "SilentlyContinue")

forEach ($import in ($public + $private))
{
    try
    {
        . $import.fullname
    }
    catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

Export-ModuleMember -Function $Public.Basename


## Define required classes used by this module
class vropsConnection {

    ## Properties
    [String]$vROPsNode
    [String]$userName
    [String]$authToken
    [string]$expiresAt
    [datetime]$creationDate
    [bool]$skipCertificates


    ## Constructor
    vropsConnection([string]$vROPsNode, [string]$userName, [string]$authToken, [string]$expiresAt, [datetime]$creationDate, [bool]$skipCertificates) {

        $this.vROPsNode = $vROPsNode
        $this.userName = $userName
        $this.authToken = $authToken
        $this.expiresAt = $expiresAt
        $this.creationDate = $creationDate
        $this.skipCertificates = $skipCertificates


    } # constructor

} # class
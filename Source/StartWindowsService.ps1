param(
    [Parameter(Mandatory=$true)]
    [string] $DisplayName,
    [int] $TimeoutSeconds = 300
)

Import-Module -Name $PSScriptRoot\Module\WindowsServices.psm1
Start-WindowsService -DisplayName $DisplayName -TimeoutSeconds $TimeoutSeconds
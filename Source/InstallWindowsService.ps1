param(
    [Parameter(Mandatory=$true)]
    [string] $ServiceName,
    [Parameter(Mandatory=$true)]
    [string] $ServiceDisplayName,
    [Parameter(Mandatory=$true)]
    [string] $Description,
    [Parameter(Mandatory=$true)]
    [string] $BinaryPath, 
    [Parameter(Mandatory=$true)]
    [string] $UserName,
    [Parameter(Mandatory=$true)]
    [securestring] $Password,
    [switch] $StartService,
    [string] $DependsOn =$null,
    [string] $StartupType="Automatic"
)

Import-Module -Name $PSScriptRoot\Module\WindowsServices.psm1
Install-WindowsService -ServiceName $ServiceName -ServiceDisplayName $ServiceDisplayName -Description $Description -BinaryPath $BinaryPath -UserName $UserName -Password $Password -StartupType $StartupType -DependsOn $DependsOn -StartService:$StartService
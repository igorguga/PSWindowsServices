param(
    [Parameter(Mandatory=$true)]
    [string] $serviceName,
    [Parameter(Mandatory=$true)]
    [string] $serviceDisplayName,
    [Parameter(Mandatory=$true)]
    [string] $description,
    [Parameter(Mandatory=$true)]
    [string] $sourcePath,
    [Parameter(Mandatory=$true)]
    [string] $destinationPath,
    [Parameter(Mandatory=$true)]
    [string] $binaryName, 
    [Parameter(Mandatory=$true)]
    [string] $userName,
    [Parameter(Mandatory=$true)]
    [securestring] $password,
    [string] $dependsOn =$null,
    [string] $startupType="Automatic"
)

Import-Module -Name $PSScriptRoot\Module\WindowsServices.psm1
 
Write-Output "Checking if the service ""$serviceDisplayName"" is installed..."
if (!(Get-Service -Name $serviceName -ErrorAction Ignore))
{
    Write-Output "Not installed! Installing service ""$serviceDisplayName""..."

    Write-Output "Copying service files to ""$destinationPath""..."
    Copy-Item -Path "$sourcePath\*" -Destination "$destinationPath" -Recurse -Force 

    Install-WindowsService -ServiceName $serviceName -BinaryPath "$destinationPath\$binaryName" -ServiceDisplayName "$serviceDisplayName" -Description "$description" -StartupType $startupType -User $userName -Password $password -DependsOn $dependsOn -StartService
    Write-Output "Done!"
}
else
{
    Write-Output "The service ""$serviceDisplayName"" is already installed."
    Stop-WindowsService -DisplayName "$serviceDisplayName"

    Write-Output "Copying new service files to ""$destinationPath""..."
    Copy-Item -Path "$sourcePath\*" -Destination "$destinationPath" -Recurse -Force 

    Start-WindowsService -DisplayName "$serviceDisplayName" 
    Write-Output "Done!"
}
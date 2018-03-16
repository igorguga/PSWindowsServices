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
    [Parameter(Mandatory=$true)]
    [AllowNull()]
    [AllowEmptyString()]
    [string] $backupFolder,
    [string] $dependsOn =$null,
    [string] $startupType="Automatic"
)

Import-Module -Name $PSScriptRoot\Module\WindowsServices.psm1
 
Write-Output "Checking if the service ""$serviceDisplayName"" is installed..."
if (!(Get-Service -Name $serviceName -ErrorAction Ignore))
{
    Write-Output "Not installed! Installing service ""$serviceDisplayName""..."
    Write-Output "Verifying if Service folder exists..."
    
    if (!(Test-Path "$sourcePath")){
        Write-Output "Creating folder ""$sourcePath"" ..."
        New-Item "$sourcePath" -itemtype directory
        Write-Output "Folder created!"
    } else {
        Write-Output "Source folder already exist."
    }

    Write-Output "Copying service files to ""$destinationPath""..."
    Copy-Item -Path "$sourcePath\*" -Destination "$destinationPath" -Recurse -Force 

    Install-WindowsService -ServiceName $serviceName -BinaryPath "$destinationPath\$binaryName" -ServiceDisplayName "$serviceDisplayName" -Description "$description" -StartupType $startupType -User $userName -Password $password -DependsOn $dependsOn -StartService
    Write-Output "Done!"
}
else
{
    Write-Output "Verifying Backup folder path."

    if(-not ([string]:: IsNullOrEmpty($backupFolder)))
    {
        Write-Output "Backup started!!"
        $name = Get-Date -Format "ddMMyyyy-hhmmss"
        if (!(Test-Path "$backupFolder\\$name")){
            Write-Output "Creating backup folder ""$backupFolder\$name""... "
            New-Item "$backupFolder\\$name" -itemtype directory
            Write-Output "Backup folder created!"
        }
        Write-Output "Copying files to Backup Folder..."
        Copy-Item -Path "$destinationPath" -Destination "$backupFolder\\$name" -Recurse -Force
        Write-Output "Backup Files copied"
    }

    Write-Output "The service ""$serviceDisplayName"" is already installed."
    Stop-WindowsService -DisplayName "$serviceDisplayName"

    Write-Output "Copying new service files to ""$destinationPath""..."
    Copy-Item -Path "$sourcePath\*" -Destination "$destinationPath" -Recurse -Force 

    Start-WindowsService -DisplayName "$serviceDisplayName" 
    Write-Output "Done!"
}
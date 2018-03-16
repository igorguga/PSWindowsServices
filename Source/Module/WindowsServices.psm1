<#
.SYNOPSIS
Starts a Windows service. 
.DESCRIPTION
Starts a Windows service in the local computer.
#>
function Start-WindowsService
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string] $DisplayName,
        [int] $TimeoutSeconds = 300
    )

    Write-Output "Checking if the service ""$DisplayName"" is not started..."
    if ($(Get-Service -DisplayName $DisplayName).Status -ne "Running" )
    {
        Write-Output "Starting service ""$DisplayName""..."
        Start-Service -DisplayName $DisplayName -ErrorAction Stop
        $count = 0
        While( ( $(Get-Service -DisplayName $DisplayName).Status -ne "Running" ))
        {
            if ($count -lt $TimeoutSeconds)
            {
                Write-Output "."
                Start-Sleep -Seconds 1
                $count++
            }
            else 
            {
                Write-Warning "Service start timeout!"
                Write-Output "The service is taking more time than expected to start. Check later if the service started or try to start it again."
            }
        }
        Write-Output "Service started!"
    }
    else {
        Write-Warning "The service ""$DisplayName"" is already started!"
    }
}


<#
.SYNOPSIS
Stops a Windows service. 
.DESCRIPTION
Stops a Windows service in the local computer.
#>
function Stop-WindowsService
{
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true)]
        [string] $DisplayName,
        [int] $TimeoutSeconds = 300
    )

    Write-Output "Checking if the service ""$DisplayName"" is already stopped..."
    if ($(Get-Service -DisplayName $DisplayName).Status -ne "Stopped" )
    {
        Write-Output "Stopping service ""$DisplayName""..."
        Stop-Service -DisplayName $DisplayName -ErrorAction Stop
        $count = 0
        While($(Get-Service -DisplayName $DisplayName).Status -ne "Stopped" )
        {
            if ($count -lt $TimeoutSeconds)
            {
                Write-Output "."
                Start-Sleep -Seconds 1
                $count++
            }
            else 
            {
                Write-Warning "Service stop timeout!"
                Write-Output "The service is taking more time than expected to stop. Check later if the service stopped or try to stop it again."
            }
        }
        Write-Output "Service stopped!"
    }
    else {
        Write-Warning "The service ""$DisplayName"" is already stopped!"
    }
}

<#
.SYNOPSIS
Removes a Windows service. 
.DESCRIPTION
Removes a Windows service from the local computer.
#>
function Uninstall-WindowsService
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string] $DisplayName,
        [int] $TimeoutSeconds = 300
    )

    Stop-WindowsService -DisplayName $DisplayName -TimeoutSeconds $TimeoutSeconds

    Write-Output "Removing service ""$DisplayName""..."
    $service = Get-WmiObject -Class Win32_Service -Filter "DisplayName='$DisplayName'" -ErrorAction Stop
    if ($service -ne $null) { 
       switch(($service.Delete()).ReturnValue)
        {
            0 {Write-Output "Service ""$DisplayName"" was removed!"}
            1 {Write-Error "The request is not supported."}
            2 {Write-Error "The user did not have the necessary access."}
            3 {Write-Error "The service cannot be stopped because other services that are running are dependent on it."}
            4 {Write-Error "The requested control code is not valid, or it is unacceptable to the service."}
            5 {Write-Error "The requested control code cannot be sent to the service because the state of the service (Win32_BaseService.State property) is equal to 0, 1, or 2."}
            6 {Write-Error "The service has not been started."}
            7 {Write-Error "The service did not respond to the start request in a timely fashion."}
            8 {Write-Error "Unknown failure when starting the service."}
            9 {Write-Error "The directory path to the service executable file was not found."}
            10 {Write-Error "The service is already running."}
            11 {Write-Error "The database to add a new service is locked."}
            12 {Write-Error "A dependency this service relies on has been removed from the system."}
            13 {Write-Error "The service failed to find the service needed from a dependent service."}
            14 {Write-Error "The service has been disabled from the system."}
            15 {Write-Error "The service does not have the correct authentication to run on the system."}
            16 {Write-Error "This service is being removed from the system."}
            17 {Write-Error "The service has no execution thread."}
            18 {Write-Error "The service has circular dependencies when it starts."}
            19 {Write-Error "A service is running under the same name."}
            20 {Write-Error "The service name has invalid characters."}
            21 {Write-Error "Invalid parameters have been passed to the service."}
            22 {Write-Error "The account under which this service runs is either invalid or lacks the permissions to run the service."}
            23 {Write-Error "The service exists in the database of services available from the system."}
            24 {Write-Error "The service is currently paused in the system."}
            default {Write-Output "Unkown return value"}
        }
    }
    else {
        Write-Error "Service ""$DisplayName"" not found! No action done."
    }
}

<#
.SYNOPSIS
Creates a Windows service. 
.DESCRIPTION
Creates a Windows service in the local computer.
#>
function Install-WindowsService
{
    [CmdletBinding()]
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

    Write-Output "Assuring that the user has ""Log on As Service"" rights..."
    Grant-LogOnAsService $UserName -ErrorAction Stop

    #Including the domain if the username didn't have one
    if ($($UserName.Split("\")).Count -lt 2)
    {
        $UserName = ".\$UserName"
    }
    $credential = New-Object System.Management.Automation.PSCredential($userName,$password)

    Write-Output "Creating service ""$ServiceDisplayName""..."
    New-Service -Name $ServiceName -BinaryPathName "$BinaryPath" -DisplayName "$ServiceDisplayName" -Description "$Description" -StartupType $StartupType -Credential $credential -DependsOn $DependsOn -ErrorAction Stop
    Write-Output "Service ""$ServiceDisplayName"" was created!"
    if ($StartService.IsPresent) {
        Start-WindowsService -DisplayName "$ServiceDisplayName"
    } 
}

<#
.SYNOPSIS
Grants logon as a Service Rights to a list of users. 
.DESCRIPTION
Grants logon as a Service Rights to a list of users in the local computer. This code was based on https://gist.github.com/ned1313/9143039
#>
function Grant-LogOnAsService
{
    [CmdletBinding()]
    param(
        [string[]] $users
    )
    
    try {
        #Get list of currently used SIDs 
        secedit /export /cfg tempexport.inf | Out-Null
        $seServiceLogon = Select-String .\tempexport.inf -Pattern "SeServiceLogonRight" 
        $currentUsers = $seServiceLogon.Line 
        $usersToGrant = ""
        foreach($user in $users){
            # Checking if it is a valid user
            $objUser = New-Object System.Security.Principal.NTAccount($user)
            $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
            if( ($strSID -ne $null) -and !$currentUsers.Contains($user)){
                $usersToGrant += ",$user"
            }
        }
        if($usersToGrant){
            $updatedUsers = $currentUsers + $usersToGrant
            Write-Output "Granting Log on As Service privileges to the users ""$users""..."
            $tempinf = Get-Content tempexport.inf
            $tempinf = $tempinf.Replace($currentUsers,$updatedUsers)
            Add-Content -Path tempimport.inf -Value $tempinf
            secedit /import /db secedit.sdb /cfg ".\tempimport.inf" | Out-Null
            secedit /configure /db secedit.sdb | Out-Null
            gpupdate /force | Out-Null
            Write-Output "Done!"
        }
        else {
            Write-Output "No new user(s) to grant Log On as Service rights."
        }
    }
    catch {
        $err = $_.Exception
        Write-Error "There was an error granting log on as service rights. Details: $err"
    }
    finally {
        #Clean up
        Remove-Item ".\tempimport.inf" -force -ErrorAction SilentlyContinue
        Remove-Item ".\secedit.sdb" -force -ErrorAction SilentlyContinue
        Remove-Item ".\tempexport.inf" -force -ErrorAction SilentlyContinue 
    } 
}

<#
.SYNOPSIS
Revoke logon as a Service Rights to a list of users. 
.DESCRIPTION
Revokes logon as a Service Rights to a list of users in the local computer. This code was based on https://gist.github.com/ned1313/9143039
#>
function Revoke-LogOnAsService
{
    [CmdletBinding()]
    param(
        [string[]] $users
    )
    
    try {
        #Get list of currently used SIDs 
        secedit /export /cfg tempexport.inf | Out-Null
        $seServiceLogon = Select-String .\tempexport.inf -Pattern "SeServiceLogonRight" 
        $currentUsers = $seServiceLogon.Line 
        $updatedUsers = $currentUsers
        foreach($user in $users){
            # Checking if it is a valid user
            $objUser = New-Object System.Security.Principal.NTAccount($user)
            $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
            if( ($strSID -ne $null) -and $updatedUsers.Contains($user)){
                $updatedUsers = $updatedUsers.Replace(",$user","")
            }
        }
        if($updatedUsers -ne $currentUsers){
            Write-Output "Revoking Log on As Service privileges to the users ""$users""..."
            $tempinf = Get-Content tempexport.inf
            $tempinf = $tempinf.Replace($currentUsers,$updatedUsers)
            Add-Content -Path tempimport.inf -Value $tempinf
            secedit /import /db secedit.sdb /cfg ".\tempimport.inf" | Out-Null
            secedit /configure /db secedit.sdb | Out-Null
            gpupdate /force | Out-Null
            Write-Output "Done!"
        }
        else {
            Write-Output "No new user(s) to revoke Log On as Service rights."
        }
    }
    catch {
        $err = $_.Exception
        Write-Error "There was an error revoking log on as service rights. Details: $err"
    }
    finally {
        #Clean up
        Remove-Item ".\tempimport.inf" -force -ErrorAction SilentlyContinue
        Remove-Item ".\secedit.sdb" -force -ErrorAction SilentlyContinue
        Remove-Item ".\tempexport.inf" -force -ErrorAction SilentlyContinue 
    } 
}
$oldConsoleColor = [console]::ForegroundColor
[console]::ForegroundColor = "Gray"

#################################################################
Write-host "###############   Pre-Requirements    ###############`n" -ForegroundColor Cyan
Write-Host "Checking if it's running as Administrator... "
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Error "You are not executing the tests with the necessary privilages. Please open a new shell ""as Administrator""." 
    exit
}

#################################################################
Write-host "`n###############        Start up       ###############`n" -ForegroundColor Cyan
Write-Host "Initializing test execution... "

$oldLocation = Get-Location
Set-Location ".."

$name = "TestWinService"
$displayName = "Windows Service Test"
$description = "This is a windows service to test deployment scripts."
$sourcePath = "$pwd\Tests\TestData\source"
$destinationPath = "$pwd\Tests\TestData\WinService"
$binaryName = "WindowsService.exe"
$userName = "TestUser"
$secpasswd = "WindowsService123" | ConvertTo-SecureString -AsPlainText -Force

Write-Host "Creating local user to be used in the tests..."
New-LocalUser -Name $userName -Password $secpasswd

Write-Host "Adding ""$userName"" to the Administrators group..."
Add-LocalGroupMember -Group "Administrators" -Member "$userName"
$failed = 0
$passed = 0

#################################################################
Write-host "`n###############    Tests execution    ###############`n" -ForegroundColor Cyan
Write-host "Running testes...`n"

try {
    Write-host "[Test01] Deploying a new Windows Service: " -NoNewline
    .\DeployWindowsService.ps1 -serviceName $name -serviceDisplayName $displayName -description $description -sourcePath $sourcePath -destinationPath $destinationPath -binaryName $binaryName -userName $userName -password $secpasswd | Out-Null
        if ($(Get-Service -Name $name).Status -eq "Running") 
        { Write-host "[OK]" -ForegroundColor Green; $passed++ }
        else 
        { Write-host "[FAILED]" -ForegroundColor Red; $failed++ }

    Write-host "[Test02] Deploying an existing Windows Service: " -NoNewline
    .\DeployWindowsService.ps1 -serviceName $name -serviceDisplayName $displayName -description $description -sourcePath $sourcePath -destinationPath $destinationPath -binaryName $binaryName -userName $userName -password $secpasswd | Out-Null
        if ($(Get-Service -Name $name).Status -eq "Running") 
        { Write-host "[OK]" -ForegroundColor Green; $passed++ }
        else 
        { Write-host "[FAILED]" -ForegroundColor Red; $failed++ }

    Write-host "[Test03] Stop a Windows Service that is running: " -NoNewline
    .\StopWindowsService.ps1 -DisplayName $displayName -TimeoutSeconds 300 | Out-Null
        if ($(Get-Service -Name $name).Status -eq "Stopped") 
        { Write-host "[OK]" -ForegroundColor Green; $passed++ }
        else 
        { Write-host "[FAILED]" -ForegroundColor Red; $failed++}

    Write-host "[Test04] Starting a Windows Service: " -NoNewline
    .\StartWindowsService.ps1 -DisplayName $displayName -TimeoutSeconds 300 | Out-Null
        if ($(Get-Service -Name $name).Status -eq "Running") 
        { Write-host "[OK]" -ForegroundColor Green; $passed++ }
        else 
        { Write-host "[FAILED]" -ForegroundColor Red; $failed++ }

    Write-host "[Test05] Uninstalling a Windows Service: " -NoNewline
    .\UninstallWindowsService.ps1 -DisplayName $displayName -TimeoutSeconds 300 | Out-Null
        if ($(Get-Service -Name $name -ErrorAction Ignore) -eq $null) 
        { Write-host "[OK]" -ForegroundColor Green; $passed++ }
        else 
        { Write-host "[FAILED]" -ForegroundColor Red; $failed++ }
    
    Write-host "[Test06] Installing a manual Windows Service without start with domain user sintax: " -NoNewline
    .\InstallWindowsService.ps1 -ServiceName $name -ServiceDisplayName $displayName -Description $description -BinaryPath "$destinationPath\$binaryName" -UserName "$env:COMPUTERNAME\$userName" -Password $secpasswd -StartupType Manual | Out-Null
        $service = $(Get-Service -Name $name -ErrorAction Ignore)
        if ( ($service -ne $null) -and $service.Status -eq "Stopped" -and $service.StartType -eq "Manual") 
        { Write-host "[OK]" -ForegroundColor Green; $passed++ }
        else 
        { Write-host "[FAILED]" -ForegroundColor Red; $failed++ }
    
    Write-host "[Test07] Start service with domain user sintax: " -NoNewline
    .\StartWindowsService.ps1 -DisplayName $displayName | Out-Null
        $service = $(Get-Service -Name $name -ErrorAction Ignore)
        if ( ($service -ne $null) -and $service.Status -eq "Running") 
        { Write-host "[OK]" -ForegroundColor Green; $passed++ }
        else 
        { Write-host "[FAILED]" -ForegroundColor Red; $failed++ }
    
    Write-host "[Test08] Stop service with domain user sintax: " -NoNewline
    .\StopWindowsService.ps1 -DisplayName $displayName | Out-Null
        $service = $(Get-Service -Name $name -ErrorAction Ignore)
        if ( ($service -ne $null) -and $service.Status -eq "Stopped") 
        { Write-host "[OK]" -ForegroundColor Green; $passed++ }
        else 
        { Write-host "[FAILED]" -ForegroundColor Red; $failed++ }

    Write-host "[Test09] Uninstalling a Windows Service not started: " -NoNewline
    .\UninstallWindowsService.ps1 -DisplayName $displayName -TimeoutSeconds 300 | Out-Null
        if ($(Get-Service -Name $name -ErrorAction Ignore) -eq $null) 
        { Write-host "[OK]" -ForegroundColor Green; $passed++ }
        else 
        { Write-host "[FAILED]" -ForegroundColor Red; $failed++ }

    Write-host "[Test10] Revoking Log On As Service for "$env:COMPUTERNAME\$userName": "-NoNewline
    try {
        Revoke-LogOnAsService "$env:COMPUTERNAME\$userName" | Out-Null
        Write-host "[OK]" -ForegroundColor Green; $passed++ 
    }
    catch {
        Write-host "[FAILED]" -ForegroundColor Red; $failed++
        throw $_.Exception
    }
}
catch {
    $failed++
    $err = $_.Exception
    Write-Error "There was an error running the tests. Details: $err"
}

finally{
    Write-Host "`n`nTotal Tests Executed: $($passed + $failed)" -ForegroundColor White
    Write-Host "Passed: $passed tests" -ForegroundColor Yellow
    Write-Host "Failed: $failed tests"-ForegroundColor Yellow

    ############### Clean up ##################################
    Write-host "`n############### Clenning up test data ###############`n" -ForegroundColor Cyan

    Write-host "Removing any remaining test service..."
    if ($(Get-Service -Name $name -ErrorAction Ignore) -ne $null)
    {
        Uninstall-WindowsService -DisplayName $displayName | Out-Null
    } 

    Write-Host "Revoking Lon On as Service privilage from user $userName..."
    Revoke-LogOnAsService $userName | Out-Null

    Write-Host "Removing local test user..."
    Remove-LocalUser -Name $userName | Out-Null

    Set-location $oldLocation 
    [console]::ForegroundColor = $oldConsoleColor
}



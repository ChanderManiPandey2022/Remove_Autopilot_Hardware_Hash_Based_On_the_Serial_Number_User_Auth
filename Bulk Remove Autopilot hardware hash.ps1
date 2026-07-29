#Remove Device from Autopilot service by removing hardware hash based on the serial number Using PowerShell
#DESCRIPTION
# Remove Device from Autopilot service by removing hardware hash based on the serial number Using PowerShell
#INPUTS
# User input needed - path to text file with serial numbers, one per line
#NOTES
#  Version:         2.0
#  Author:          Chander Mani Pandey, 
#  Creation Date:   28 July 2024
#  Updated :        29 July 2026   | fixed to use GA cmdlets pinned to 2.28.0 + 
#                   switched to Invoke-MgGraphRequest to avoid AggregateException
#                   thrown by Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -All
#  Find Author on
#  Youtube:-        https://www.youtube.com/@chandermanipandey8763
#  Twitter:-        https://twitter.com/Mani_CMPandey
#  LinkedIn:-       https://www.linkedin.com/in/chandermanipandey

Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

#=================================User Input Section==========================

# Load serial numbers from a text file. Change this path based on your environment.
$Devices = Get-Content "C:\Users\CM\Downloads\SerialNumber1.txt"

#=============================================================================

$requiredVersion = "2.28.0"
$moduleName = "Microsoft.Graph.DeviceManagement.Enrollment"

Write-Host "Checking if '$moduleName' version $requiredVersion is installed..."

$MGIModule = Get-Module -Name $moduleName -ListAvailable | Where-Object { $_.Version -eq $requiredVersion }

if ($null -eq $MGIModule) {
    Write-Host "Module not found at required version. Installing $moduleName $requiredVersion ..." -ForegroundColor Yellow
    Install-Module $moduleName -Force -RequiredVersion $requiredVersion -Scope CurrentUser
}

Import-Module $moduleName -RequiredVersion $requiredVersion -Force

# Connect to Microsoft Graph (interactive). Add -Scopes if consent hasn't already been granted.
Connect-MgGraph -Scopes "DeviceManagementServiceConfig.ReadWrite.All" -ContextScope Process

# Confirm what scopes / account are actually active - useful if you hit permission errors
$ctx = Get-MgContext
Write-Host "Connected as: $($ctx.Account)" -ForegroundColor Cyan
Write-Host "Granted scopes: $($ctx.Scopes -join ', ')" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Retrieve all Autopilot device identities via direct Graph REST calls.
# This avoids the AggregateException that Get-MgDeviceManagementWindowsAutopilotDeviceIdentity -All
# can throw on some tenants/module builds when paging internally.
# ---------------------------------------------------------------------------
Write-Host "Retrieving all Autopilot device identities..." -ForegroundColor Cyan

$allAutopilot = @()
$uri = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities"

try {
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        $allAutopilot += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)
} catch {
    Write-Host "Failed to retrieve Autopilot device identities." -ForegroundColor Red
    $_.Exception | Format-List * -Force
    if ($_.Exception.InnerException) {
        $_.Exception.InnerException | Format-List * -Force
    }
    throw
}

Write-Host "Retrieved $($allAutopilot.Count) Autopilot device identities." -ForegroundColor Cyan

# Initialize result lists
$notFoundDevices = @()
$successfulRemovals = @()
$failedRemovals = @()

# Remove devices whose serial number matches the input list
foreach ($device in $Devices) {
    # REST payload uses camelCase property names: serialNumber, id
    $deviceToRemove = $allAutopilot | Where-Object { $_.serialNumber -eq $device }

    if ($deviceToRemove) {
        try {
            $deleteUri = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities/$($deviceToRemove.id)"
            Invoke-MgGraphRequest -Method DELETE -Uri $deleteUri -ErrorAction Stop | Out-Null
            Write-Host "The device with the following serial number is now removed successfully: $($deviceToRemove.serialNumber)" -ForegroundColor Green
            $successfulRemovals += [PSCustomObject]@{ SerialNumber = $deviceToRemove.serialNumber }
        } catch {
            Write-Host "Failed to remove the device with serial number: $($deviceToRemove.serialNumber) - $($_.Exception.Message)" -ForegroundColor Red
            $failedRemovals += [PSCustomObject]@{ SerialNumber = $deviceToRemove.serialNumber; Error = $_.Exception.Message }
        }
    } else {
        Write-Host "Device with serial number $device not found." -ForegroundColor Yellow
        $notFoundDevices += [PSCustomObject]@{ SerialNumber = $device }
    }
}

# Save results to CSV files
$notFoundDevices     | Export-Csv -Path "C:\Windows\Temp\NotFoundDevices.csv" -NoTypeInformation
$successfulRemovals  | Export-Csv -Path "C:\Windows\Temp\SuccessfulRemovals.csv" -NoTypeInformation
$failedRemovals      | Export-Csv -Path "C:\Windows\Temp\FailedRemovals.csv" -NoTypeInformation

# Print summary
Write-Host ""
Write-Host "Total Device Serial Numbers in input file:    $($Devices.Count)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total successful removals:                    $($successfulRemovals.Count)" -ForegroundColor Green
Write-Host "Total devices not found:                       $($notFoundDevices.Count)" -ForegroundColor Yellow
Write-Host "Total failed removals:                         $($failedRemovals.Count)" -ForegroundColor Red
Write-Host ""

Write-Host ("[{0}] NotFoundDevices saved to C:\Windows\Temp\NotFoundDevices.csv" -f (Get-Date)) -ForegroundColor Yellow
Write-Host ("[{0}] SuccessfulRemovals saved to C:\Windows\Temp\SuccessfulRemovals.csv" -f (Get-Date)) -ForegroundColor Yellow
Write-Host ("[{0}] FailedRemovals saved to C:\Windows\Temp\FailedRemovals.csv" -f (Get-Date)) -ForegroundColor Yellow

Disconnect-MgGraph
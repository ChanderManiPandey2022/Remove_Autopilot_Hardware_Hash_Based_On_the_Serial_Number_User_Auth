
#Remove Device from Autopilot service by removing hardware hash based on the serial number Using PowerShell>
#DESCRIPTION
 <# Remove Device from Autopilot service by removing hardware hash based on the serial number Using PowerShel>
 #INPUTS
 < User Imput Needed>
#NOTES
  Version:        1.0
  Author:         Chander Mani Pandey
  Creation Date:  28 July 2024
  Find Author on 
  Youtube:-        https://www.youtube.com/@chandermanipandey8763
  Twitter:-        https://twitter.com/Mani_CMPandey
  LinkedIn:-       https://www.linkedin.com/in/chandermanipandey
  
 #>

Set-ExecutionPolicy -ExecutionPolicy Bypass

#=================================User Input Section==========================

# Load serial numbers from a text file. You can change this path based on your choice.
$Devices = Get-Content "C:\Windows\Temp\SerialNumber.txt"



#=============================================================================

$MGIModule = Get-module -Name "Microsoft.Graph.Beta.DeviceManagement.Enrollment" -ListAvailable
Write-Host "Checking if 'Microsoft.Graph.Beta.DeviceManagement.Enrollment' is installed"

if ($MGIModule -eq $null) {
    Write-Host "Microsoft.Graph.Beta.DeviceManagement.Enrollment is not installed"
    Write-Host "Installing Microsoft.Graph.Beta.DeviceManagement.Enrollment" -ForegroundColor Yellow
    Install-Module Microsoft.Graph.Beta.DeviceManagement.Enrollment -Force
    Write-Host "Microsoft.Graph.Beta.DeviceManagement.Enrollment is Installed" -ForegroundColor Green
    Write-Host "Importing Microsoft.Graph.Beta.DeviceManagement.Enrollment module"-ForegroundColor Yellow
   Write-Host "Microsoft.Graph.Beta.DeviceManagement.Enrollment module imported successfully" -ForegroundColor Green
} else {
    Write-Host "Microsoft.Graph.Beta.DeviceManagement.Enrollment is installed" -ForegroundColor Green
    Write-Host "Importing Microsoft.Graph.Beta.DeviceManagement.Enrollment module"-ForegroundColor Yellow
    Import-Module Microsoft.Graph.Beta.DeviceManagement.Enrollment -Force
    Write-Host "Microsoft.Graph.Beta.DeviceManagement.Enrollment module imported successfully" -ForegroundColor Green

}

# Connect to Microsoft Graph with Client Secret
Connect-MgGraph 

#Connect-MgGraph -Scopes DeviceManagementServiceConfig.ReadWrite.All

# Query Microsoft Graph Endpoints and filter for conditions
$allAutopilot = Get-MgBetaDeviceManagementWindowsAutopilotDeviceIdentity 


# Initialize lists
$notFoundDevices = @()
$successfulRemovals = @()
$failedRemovals = @()

# Delete stale devices !On your own responsibility - no liability!
foreach ($device in $Devices) {
    $deviceToRemove = $allAutopilot | Where-Object { $_.SerialNumber -eq $device }
    if ($deviceToRemove) {
        try {
            Remove-MgBetaDeviceManagementWindowsAutopilotDeviceIdentity -WindowsAutopilotDeviceIdentityId $deviceToRemove.Id
            Write-Host "The device with the following serial number is now removed successfully: $($deviceToRemove.SerialNumber)" -ForegroundColor Green
            $successfulRemovals += [PSCustomObject]@{ SerialNumber = $deviceToRemove.SerialNumber }
        } catch {
            Write-Host "Failed to remove the device with serial number: $($deviceToRemove.SerialNumber)" -ForegroundColor Red
            $failedRemovals += [PSCustomObject]@{ SerialNumber = $deviceToRemove.SerialNumber }
        }
    } else {
        Write-Host "Device with serial number $device not found." -ForegroundColor Yellow
        $notFoundDevices += [PSCustomObject]@{ SerialNumber = $device }
    }
}

# Save results to CSV files
$notFoundDevices | Export-Csv -Path "C:\Windows\Temp\NotFoundDevices.csv" -NoTypeInformation
$successfulRemovals | Export-Csv -Path "C:\Windows\Temp\SuccessfulRemovals.csv" -NoTypeInformation
$failedRemovals | Export-Csv -Path "C:\Windows\Temp\FailedRemovals.csv" -NoTypeInformation

# Print summary
Write-Host ""
Write-Host "Total Device Serial Number in Notepad file:       $($Devices.count)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total successful removal:                     $($successfulRemovals.Count)" -ForegroundColor Green
Write-Host "Total devices not found:                      $($notFoundDevices.Count)" -ForegroundColor Yellow
Write-Host "Total failed removal:                         $($failedRemovals.Count)" -ForegroundColor Red
Write-Host ""


# Save results to CSV files

# Save NotFoundDevices and write host message with timestamp
Write-Host ("[{0}] NotFoundDevices saved to C:\Windows\Temp\NotFoundDevices.csv" -f (Get-Date)) -ForegroundColor Yellow

# Save SuccessfulRemovals and write host message with timestamp
Write-Host ("[{0}] SuccessfulRemovals saved to C:\Windows\Temp\SuccessfulRemovals.csv" -f (Get-Date)) -ForegroundColor Yellow

# Save FailedRemovals and write host message with timestamp
Write-Host ("[{0}] FailedRemovals saved to C:\Windows\Temp\FailedRemovals.csv" -f (Get-Date)) -ForegroundColor Yellow


Disconnect-MgGraph


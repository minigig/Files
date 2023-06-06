$logFolder = 'C:\temp\logs'
if (!(Test-Path -Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -ErrorAction SilentlyContinue | Out-Null
}

$logFile = Join-Path -Path $logFolder -ChildPath 'error.log'

Write-Host "Leaving Azure AD..." -ForegroundColor Green
Start-Process -FilePath "dsregcmd" -ArgumentList "/leave" -NoNewWindow -Wait

$profileList = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'

$excludeProfiles = @("IDS", "Default", "Public", "S-1-5-18", "S-1-5-19", "S-1-5-20")

# Set the base directory
$baseDirectory = "C:\temp\bookmarks"

# Create the base directory if it does not exist
if (!(Test-Path -Path $baseDirectory)) {
    New-Item -ItemType Directory -Force -Path $baseDirectory
}

foreach ($sid in $profileList) {
    if ($excludeProfiles -notcontains $sid.PSChildName) {
        $username = $sid.GetValue('ProfileImagePath').Split('\')[-1]

        # Check if this username should be excluded
        if ($excludeProfiles -notcontains $username) {
            Write-Host "Processing profile: $($sid.PSChildName): $username" -ForegroundColor Cyan

            $folderToDelete = "C:\users\$username"
            $renamedFolder = "$folderToDelete.old"

            # Set the Chrome and Edge directories
            $chromeDirectory = Join-Path -Path $baseDirectory -ChildPath "$username-chrome"
            $edgeDirectory = Join-Path -Path $baseDirectory -ChildPath "$username-edge"

            # Create the directories if they do not exist
            if (!(Test-Path -Path $chromeDirectory)) {
                New-Item -ItemType Directory -Force -Path $chromeDirectory
            }
            if (!(Test-Path -Path $edgeDirectory)) {
                New-Item -ItemType Directory -Force -Path $edgeDirectory
            }

            # Define the path to the Chrome and Edge bookmarks file in the user's profile
            $chromeBookmarksPath = Join-Path -Path $folderToDelete -ChildPath "AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
            $edgeBookmarksPath = Join-Path -Path $folderToDelete -ChildPath "AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"

            # Copy the bookmarks files to the respective directories
            if (Test-Path -Path $chromeBookmarksPath) {
                Copy-Item -Path $chromeBookmarksPath -Destination $chromeDirectory
            }
            if (Test-Path -Path $edgeBookmarksPath) {
                Copy-Item -Path $edgeBookmarksPath -Destination $edgeDirectory
            }

            # Change permissions to read and write for all users
            $acl = Get-Acl -Path $folderToDelete
            $acl.SetAccessRuleProtection($false, $true)
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")
            $acl.AddAccessRule($accessRule)
            Set-Acl -Path $folderToDelete -AclObject $acl

            try {
                Rename-Item -Path $folderToDelete -NewName $renamedFolder -ErrorAction Stop
                # Check if the renaming was successful
                if (Test-Path $renamedFolder) {
                    Write-Host "$folderToDelete renamed successfully to $renamedFolder" -ForegroundColor Green
                } else {
                    Write-Host "Failed to rename $folderToDelete" -ForegroundColor Red
                }
            } catch {
                Write-Host "An error occurred while renaming $folderToDelete. Check the log file for more information." -ForegroundColor Yellow
                $_ | Out-File -Append -FilePath $logFile
            }

            wmic path win32_userprofile where "sid='$($sid.PSChildName)'" delete
        }
    }
}

$sids = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked' -name | where-object { $_.Length -gt 25 }

foreach ($sid in $sids){
    if ($excludeProfiles -notcontains $sid) {
        Write-Host "Found a registered device. Removing the device registration settings for SID: $sid" -ForegroundColor Yellow

        $enrollmentpath = "HKLM:\SOFTWARE\Microsoft\Enrollments\$sid"
        $entresourcepath = "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\$sid"

        if (Test-Path $enrollmentpath) {
            Write-Host "$sid exists and will be removed" -ForegroundColor Red
            Remove-Item -Path $enrollmentpath -Recurse -Confirm:$false
            Remove-Item -Path $entresourcepath -Recurse -Confirm:$false
        } else {
            Write-Host "The value does not exist, skipping" -ForegroundColor Green
        }

        Get-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\$sid\*" | Unregister-ScheduledTask -Confirm:$false
        $scheduleObject = New-Object -ComObject Schedule.Service
        $scheduleObject.connect()
        $rootFolder = $scheduleObject.GetFolder("\Microsoft\Windows\EnterpriseMgmt")
        $rootFolder.DeleteFolder($sid, $null)

        Write-Host "Device registration cleaned up for $sid. If there is more than 1 device registration, we will continue to the next one." -ForegroundColor Cyan
    }
}

Write-Host "Cleanup of device registration has been completed. Removal of the old tenant is completed , please open settings from the windows menu and go to accounts and access work and school , then click on the connect button and then under Join this device to Azure Active Directory" -ForegroundColor Green

# Keep window open
cmd /c "pause"

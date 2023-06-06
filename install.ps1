Try {
    # Get 'temp' item in C:\ if it exists
    $tempItem = Get-Item -Path "C:\temp" -ErrorAction SilentlyContinue

    # If it's a file, not a directory, delete it
    if ($tempItem -and $tempItem -isnot [System.IO.DirectoryInfo]) {
        Remove-Item -Path "C:\temp" -Force
    }

    # Create a new temp directory if it does not exist
    if (!(Test-Path "C:\temp")) {
        New-Item -ItemType Directory -Force -Path "C:\temp"
    }

 # Copy Migration.ps1 and mig.ico to the new temp directory
 Copy-Item -Path "$PSScriptRoot\Migration.ps1" -Destination "C:\temp"
 Copy-Item -Path "$PSScriptRoot\mig.ico" -Destination "C:\temp"


# Create .bat file to run Migration.ps1 as admin with unrestricted execution policy
$batContent = '@echo off' + "`r`n" + 'PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& { Start-Process PowerShell -ArgumentList ''-NoProfile -ExecutionPolicy Bypass -File "C:\temp\Migration.ps1"'' -Verb RunAs}"'
$batFilePath = "C:\temp\RunMigration.bat"
$batContent | Out-File -FilePath $batFilePath -Encoding ASCII





    # Set permissions to allow all users to read and write the .bat and .ps1 files
    $filesToChangePermissions = @("C:\temp\Migration.ps1", $batFilePath)

    foreach ($file in $filesToChangePermissions) {
        $acl = Get-Acl -Path $file
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Users","FullControl","Allow")
        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $file -AclObject $acl
    }

   # Define the IDS user's desktop path
$idsDesktopPath = "C:\Users\IDS\Desktop"

# Check if the path exists
if (-not (Test-Path $idsDesktopPath)) {
    # If not, create the directory
    New-Item -ItemType Directory -Path $idsDesktopPath -Force
}

# Define a new COM object for creating the shortcut
$WshShell = New-Object -ComObject WScript.Shell

# Create a new shortcut on the desktop
$Shortcut = $WshShell.CreateShortcut("$idsDesktopPath\RunMigration.lnk")
$Shortcut.TargetPath = $batFilePath
$Shortcut.IconLocation = "C:\temp\mig.ico"
$Shortcut.Save()

# Set permissions to allow all users to read and write the .lnk file
$acl = Get-Acl -Path $Shortcut.FullName
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Users","FullControl","Allow")
$acl.SetAccessRule($accessRule)
Set-Acl -Path $Shortcut.FullName -AclObject $acl

# Iterate over each sub-directory in the target path, applying permissions
$pathParts = $Shortcut.TargetPath -split '\\'
for ($i = 0; $i -lt $pathParts.Count; $i++) {
    $currentPath = [System.IO.Path]::Combine($pathParts[0..$i])
    if (Test-Path $currentPath) {
        $acl = Get-Acl -Path $currentPath
        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $currentPath -AclObject $acl
    }
}

# Everything went well, exit with code 0
exit 0

}
Catch {
    Write-Host $_.Exception.Message
    # Something went wrong, exit with code 1
    exit 1
}


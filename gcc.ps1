# Enable or disable debugging by setting the $Debugging variable to $true or $false
# When debugging is enabled, the script will print verbose information at each stage,
# wait for the user to press any key to continue, and create a log file in C:\temp\logs

# Ensure the script is run with administrator privileges.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as an administrator."
    exit
}

# Debugging variable
$Debugging = $true
$LogFile = "C:\temp\logs\debug.log"

function Write-DebugInfo($Message) {
    if ($Debugging) {
        Write-Host $Message
        Add-Content -Path $LogFile -Value $Message
    }
}

# Create the log folder if it does not exist
if ($Debugging -and (-not (Test-Path (Split-Path $LogFile -Parent)))) {
    New-Item -ItemType Directory -Path (Split-Path $LogFile -Parent) -Force
}

# Unjoin the device from Azure AD.
Write-DebugInfo "Unjoining the device from Azure AD..."
dsregcmd /leave
Write-DebugInfo "Device successfully unjoined from Azure AD"


# Identify the main user account based on the user profile folder size.
$ProfilesRoot = "C:\Users"
$ExcludeAccounts = @("IDS", "Public", "Default", "Default User")
$MainProfilePath = Get-ChildItem -Path $ProfilesRoot -Directory | Where-Object { $_.Name -notin $ExcludeAccounts } | Sort-Object { (Get-ChildItem -Path $_.FullName -Recurse -Force | Measure-Object -Property Length -Sum).Sum } -Descending | Select-Object -First 1 -ExpandProperty FullName

# Set permissions to allow all users to read the main user profile folder.
#Write-DebugInfo "Setting permissions to allow all users to read the main user profile folder..."
#$Acl = Get-Acl -Path $MainProfilePath
#$AllUsers = New-Object System.Security.Principal.SecurityIdentifier("S-1-1-0")
#$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AllUsers, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
#$Acl.AddAccessRule($AccessRule)
#Set-Acl -Path $MainProfilePath -AclObject $Acl
#Write-DebugInfo "Permissions set successfully"


# Copy the main user account's AppData folder to C:\temp\profile.
$AppDataPath = Join-Path $MainProfilePath "AppData"
$DestinationPath = "C:\temp\profile"

if (-not (Test-Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath -Force
}

$ErrorActionPreference = "SilentlyContinue"
Get-ChildItem -Path $AppDataPath -Recurse -Force | ForEach-Object {
    $SourcePath = $_.FullName
    $RelativePath = $SourcePath.Substring($AppDataPath.Length)
    $TargetPath = Join-Path $DestinationPath $RelativePath

    try {
        if ($_.PSIsContainer) {
            New-Item -ItemType Directory -Path $TargetPath -Force
            Write-DebugInfo "Created folder: $TargetPath"
        } else {
            Copy-Item -Path $SourcePath -Destination $TargetPath -Force
            Write-DebugInfo "Copied file: $SourcePath to $TargetPath"
        }
    } catch {
        Write-DebugInfo "Failed to copy: $SourcePath"
        Add-Content -Path $LogFile -Value "Failed to copy: $SourcePath"
    }
}


# Set permissions to the Startup folder to ensure the script can create the .bat file.
$StartupPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
$Acl = Get-Acl -Path $StartupPath
$AllUsers = New-Object System.Security.Principal.SecurityIdentifier("S-1-1-0")
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AllUsers, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
$Acl.AddAccessRule($AccessRule)
Set-Acl -Path $StartupPath -AclObject $Acl
Write-DebugInfo "Permissions for the Startup folder have been set"

# Create the .bat file in the Startup folder.
$BatFilePath = Join-Path $StartupPath "MigrateData.bat"
$BatchContent = @"
@echo off
setlocal

for /f "tokens=1,2" %%a in ('qwinsta ^| findstr /C:">"') do (
    set "CurrentUser=%%b"
)

if /i "%CurrentUser%"=="IDS" (
    echo Migrating stored AppData to the new user's AppData folder...
    powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy RemoteSigned -File C:\temp\CopyAppDataToNewUser.ps1' -Verb RunAs"
    echo Migration completed.
    del "%~f0"
    echo Removing startup files...
    powershell -Command "Remove-Item -Path '$StartupPath\*' -Force"
) else (
    echo Please reboot into the IDS account to migrate your data. The system will force a reboot in 15 seconds.
    timeout /t 15 /nobreak > nul
    shutdown /r /t 0
)
"@

Set-Content -Path $BatFilePath -Value $BatchContent
Write-Host "Created .bat file in the Startup folder"
#Read-Host "Press Enter to continue..."


$CopyScriptPath = "C:\temp\CopyAppDataToNewUser.ps1"
$CopyScriptContent = @'
# Enable or disable debugging by setting the `$Debugging variable to `$true or `$false
# When debugging is enabled, the script will print verbose information at each stage,
# wait for the user to press any key to continue, and create a log file in C:\temp\logs

$Debugging = $true
$LogFile = "C:\temp\logs\CopyAppDataToNewUser.log"

function Write-DebugInfo($Message) {
    if ($Debugging) {
        Write-Host $Message
        Add-Content -Path $LogFile -Value $Message
    }
}

# Create the log folder if it does not exist
if ($Debugging -and (-not (Test-Path (Split-Path $LogFile -Parent)))) {
    New-Item -ItemType Directory -Path (Split-Path $LogFile -Parent) -Force
}

try {
    $UsersPath = "C:\Users"
    $ExcludedProfiles = @("IDS", "Public", "Default")
    $NewestProfile = Get-ChildItem -Path $UsersPath | Where-Object { $_.PSIsContainer -and $ExcludedProfiles -notcontains $_.Name } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $DestinationAppData = Join-Path $NewestProfile.FullName "AppData"

    $Acl = Get-Acl $DestinationAppData
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $Acl.AddAccessRule($AccessRule)
    Set-Acl -Path $DestinationAppData -AclObject $Acl

    $SourceAppData = "C:\temp\profile"
    Get-ChildItem -Path $SourceAppData -Recurse -Force | ForEach-Object {
        $SourcePath = $_.FullName
        $RelativePath = $SourcePath.Substring($SourceAppData.Length)
        $TargetPath = Join-Path $DestinationAppData $RelativePath

        try {
            if ($_.PSIsContainer) {
                New-Item -ItemType Directory -Path $TargetPath -Force
                Write-DebugInfo "Created folder: $TargetPath"
            } else {
                Copy-Item -Path $SourcePath -Destination $TargetPath -Force
                Write-DebugInfo "Copied file: $SourcePath to $TargetPath"
            }
        } catch {
            Write-DebugInfo "Failed to copy: $SourcePath"
            Add-Content -Path $LogFile -Value "Failed to copy: $SourcePath"
        }
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    Write-DebugInfo "Error: $($_.Exception.Message)"
    
    exit
}
$GCCMigrationFile = "C:\Users\Public\Desktop\GCC-Migration.bat.lnk"
if (Test-Path $GCCMigrationFile) {
    Remove-Item $GCCMigrationFile -Force
    Write-DebugInfo "Removed file: $GCCMigrationFile"
}

Restart-Computer -Force

'@

Set-Content -Path $CopyScriptPath -Value $CopyScriptContent


# Configure the device to boot into OOBE mode and generalize the system.
Write-Host "Configuring the device to reboot into OOBE mode and generalize the system..."
cmd /c "C:\Windows\System32\Sysprep\sysprep.exe /oobe /reboot"

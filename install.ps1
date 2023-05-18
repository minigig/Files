#Specify the source files
$sourceFiles = "GCC-Migration.bat", "GCCHIGH.ps1"

#Specify the destination folder
$destFolder = "C:\temp"

#Copy each file to the destination folder
foreach ($file in $sourceFiles)
{
    #Check if the file exists
    if (Test-Path $file)
    {
        Copy-Item -Path $file -Destination $destFolder
    }
    else
    {
        Write-Output "File $file does not exist"
    }
}

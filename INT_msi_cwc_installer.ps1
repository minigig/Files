???# Variables
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$CWControlDownloadURL = "https://control.sentinelblue.com/Bin/ConnectWiseControl.ClientSetup.msi?h=control.sentinelblue.us&p=443&k=BgIAAACkAABSU0ExAAgAAAEAAQBJ5%2BV4rzLaktESZsCc4JA9WIubFOj5Xw%2Bp%2BeYGzZxB18umkDteFvbiiEjiHvjKyUulXRDq%2FjOvxP4Fm8MXam7iNg3jAVujUs%2BKf1%2Bo0ztQR3QmNxDEVrxcC6HUtd%2BY5lfjAKgEafnSmJ5mx%2Bb47PMsc9JjcsiuoD4JuRC2seSfq7K2ozLrDiWLlRkVAF%2BHdTWsTUbStQDwOwrEI2zRyE%2BAKre4w9N3cTey5c8g%2BGabvy57I8vVxXMqTIPXNFqvZIxriadqtIJWiGVQGFAefKDGIs9yu3XTZLoVxl9tOMwnx%2BkLfF%2BIPxhNf4csB%2FFQ5wJ74NwuTY1r%2BsOQ2x5DJ22u&e=Access&y=Guest&t=&c=INT&c=Main&c=&c=&c=&c=&c=&c="

if (!$CWControlDownloadURL) {
    Write-Host "The CW Control Download URL has not been specified. Check the Site Settings for this site."
    }
else {
    try {
    $localInstaller = "$env:temp\ConnectWiseControl.ClientSetup.msi";
    Invoke-WebRequest -Uri $CWControlDownloadURL -OutFile $localInstaller;
    & msiexec.exe /i $localInstaller /qn;

    Start-Sleep -Seconds 180
    Remove-Item $localInstaller
    Write-Host "The installation was successful."
    }

    catch {
    Write-Host "The installation was not successful."
    }
}

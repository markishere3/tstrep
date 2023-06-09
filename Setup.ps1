function Write-HostCenter { param($Message) Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Message.Length / 2)))), $Message) }

function Set-DefaultBrowser
{
    param($defaultBrowser)

    $regKey      = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\{0}\UserChoice"
    $regKeyFtp   = $regKey -f 'ftp'
    $regKeyHttp  = $regKey -f 'http'
    $regKeyHttps = $regKey -f 'https'

    switch -Regex ($defaultBrowser.ToLower())
    {
        # Internet Explorer
        'ie|internet|explorer' {
            Set-ItemProperty $regKeyFtp   -name ProgId IE.FTP
            Set-ItemProperty $regKeyHttp  -name ProgId IE.HTTP
            Set-ItemProperty $regKeyHttps -name ProgId IE.HTTPS
            break
        }
        # Firefox
        'ff|firefox' {
            Set-ItemProperty $regKeyFtp   -name ProgId FirefoxURL
            Set-ItemProperty $regKeyHttp  -name ProgId FirefoxURL
            Set-ItemProperty $regKeyHttps -name ProgId FirefoxURL
            break
        }
        # Google Chrome
        'cr|google|chrome' {
            Set-ItemProperty $regKeyFtp   -name ProgId ChromeHTML
            Set-ItemProperty $regKeyHttp  -name ProgId ChromeHTML
            Set-ItemProperty $regKeyHttps -name ProgId ChromeHTML
            break
        }
        # Safari
        'sa*|apple' {
            Set-ItemProperty $regKeyFtp   -name ProgId SafariURL
            Set-ItemProperty $regKeyHttp  -name ProgId SafariURL
            Set-ItemProperty $regKeyHttps -name ProgId SafariURL
            break
        }
        # Opera
        'op*' {
            Set-ItemProperty $regKeyFtp   -name ProgId Opera.Protocol
            Set-ItemProperty $regKeyHttp  -name ProgId Opera.Protocol
            Set-ItemProperty $regKeyHttps -name ProgId Opera.Protocol
            break
        }
    } 

}

Write-HostCenter "Mark's Cloud Gaming Preperation Script!"
Write-Host ""

If (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "You are not admin!"
}

Try {
    (Invoke-WebRequest -uri http://169.254.169.254/latest/meta-data/ -TimeoutSec 5)
    }
catch {
    throw "Unsupported cloud provider!"
}

Write-Host "Currently, only g4dn.xlarge is supported for this script. In the future, I may try to figure it out if I can get enough help from everybody."

Write-Host "Before we install things, we need to know your preferences."

$prefferedStreamingService = (Read-Host "What streaming service do you wish to install? (Parsec/Sunshine)").ToLower()

$isSupportedSS = $false

if($prefferedStreamingService -imatch "parsec") 
{
    $isSupportedSS = $true
}

if($prefferedStreamingService -imatch "sunshine") 
{
    $isSupportedSS = $true
    Write-Host "Currently, Sunshine crashes after installing DirectX runtimes. Please keep this in mind! I do not know how to fix it!"
}

if(!$isSupportedSS)
{
    Write-Host "Your service is currently not supported, you will need to install it yourself after!"
}

Start-Sleep 5

Clear-Host

Write-HostCenter "Applications"
$shouldInstallChrome = (Read-Host "Should we install Chrome for you? (y/n)").ToLower()

$shouldMakeChromeDefault = (Read-Host "Should we make Chrome default for you? [BROKEN!] (y/n)").ToLower()

$shouldInstallSteam = (Read-Host "Should we install Steam for you? (y/n)").ToLower()

$shouldInstallEpicGames = (Read-Host "Should we install Epic Games Launcher for you? (y/n)").ToLower()

$shouldInstallDiscord = (Read-Host "Should we install Discord for you? (y/n)").ToLower()

Start-Sleep 2

Clear-Host

Write-HostCenter "Drivers"
$shouldInstallDrivers = (Read-Host "Should we install video card drivers for you? (y/n)").ToLower()

$shouldInstallVCRedist = (Read-Host "Should we install Visual C++ Redistributable for Visual Studio 2015 (x86) for you? (y/n)").ToLower()

$shouldInstallViGEm = (Read-Host "Do you wish to install ViGEm? [For controller passthrough] [BROKEN!] (y/n)").ToLower()

$shouldInstallVBCable = (Read-Host "Should we install VBCable for you? [This is for audio transmission!] (y/n)").ToLower()

Clear-Host

$shouldAutoRestart = (Read-Host "Should the script automatically restart for you? (y/n)").ToLower()

Clear-Host

$password = Read-Host "You are required to enter a new password, please enter a new password" 

Clear-Host

$AWSACCESSKEY = Read-Host "You are unfortunately required to give an access key and secret key, due to AWS having exclusive drivers. Please input your Access Key" -

Clear-Host

$AWSSECRETKEY = Read-Host "Please input your Secret Key"

Clear-Host

Write-HostCenter "Please wait, setting the keys!"

Set-AWSCredential -AccessKey $AWSACCESSKEY -SecretKey $AWSSECRETKEY -StoreAs MyNewProfile
Set-AWSCredential -ProfileName MyNewProfile

Clear-Host

Write-HostCenter "Success!"

Start-Sleep 2

Write-HostCenter "Checking for folders, please wait!"

$WorkingDir = (Get-Location).Path.ToString()

If(-not (Test-Path -Path $WorkingDir\Downloads))
{
    New-Item -Path "$WorkingDir\Downloads" -ItemType Directory
}


Clear-Host 

Write-HostCenter "Installation Started!"


if($shouldInstallDrivers -imatch "y")
{
    Write-HostCenter "GPU Drivers"
    $Bucket = "nvidia-gaming"
    $KeyPrefix = "windows/latest"
    $LocalPath = "$home\Desktop\NVIDIA"
    $Objects = Get-S3Object -BucketName $Bucket -KeyPrefix $KeyPrefix -Region us-east-1
    
    Write-Host "Downloading Drivers..."
    foreach ($Object in $Objects) {
        $LocalFileName = $Object.Key
        if ($LocalFileName -ne '' -and $Object.Size -ne 0) {
            $LocalFilePath = Join-Path $LocalPath $LocalFileName
            Copy-S3Object -BucketName $Bucket -Key $Object.Key -LocalFile $LocalFilePath -Region us-east-1
        }
    }
    
    Write-Host "Download Complete!"
    
    Write-Host "Installing Drivers..."
    Start-Process -FilePath "$LocalFilePath" -ArgumentList "/s /n" -Wait 
    
    Write-Host "Install complete!"
    
    Write-Host "Setting required properties..."
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global" -Name "vGamingMarketplace" -PropertyType "DWord" -Value "2"
    
    Invoke-WebRequest -Uri "https://nvidia-gaming.s3.amazonaws.com/GridSwCert-Archive/GridSwCertWindows_2021_10_2.cert" -OutFile "$Env:PUBLIC\Documents\GridSwCert.txt"
    
    Write-Host "Done!"
    
    Clear-Host

    #This is from Parsec's cloud preperation tool!
    Write-HostCenter "Disabling unnecessary adapters...."
    Get-PnpDevice | where {$_.friendlyname -like "Generic Non-PNP Monitor" -and $_.status -eq "OK"} | Disable-PnpDevice -confirm:$false
    Get-PnpDevice | where {$_.friendlyname -like "Microsoft Basic Display Adapter" -and $_.status -eq "OK"} | Disable-PnpDevice -confirm:$false
    Get-PnpDevice | where {$_.friendlyname -like "Google Graphics Array (GGA)" -and $_.status -eq "OK"} | Disable-PnpDevice -confirm:$false
    Get-PnpDevice | where {$_.friendlyname -like "Microsoft Hyper-V Video" -and $_.status -eq "OK"} | Disable-PnpDevice -confirm:$false
    Write-Host "Complete!"

    Clear-Host
}

Write-HostCenter "Applications"

if($shouldInstallChrome -imatch "y")
{
    Write-Host "Downloading Chrome...."
    (New-Object System.Net.WebClient).DownloadFile("https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BADB34C44-5FAF-9B9B-F138-0D6C4BC5BC24%7D%26lang%3Den%26browser%3D3%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1%26installdataindex%3Dempty/chrome/install/ChromeStandaloneSetup64.exe", "$WorkingDir\Downloads\ChromeStandaloneSetup64.exe")
    Write-Host "Complete!"

    Write-Host "Installing Chrome..."
    Start-Process $WorkingDir\Downloads\ChromeStandaloneSetup64.exe -Wait
    Write-Host "Chrome successfully installed!"
    Write-Host ""
}

if($shouldMakeChromeDefault -imatch "y")
{
    Write-Host "Making chrome default is currently not functional and will be fixed in a later update."
    Set-DefaultBrowser cr
    Write-Host ""
}

if($shouldInstallSteam -imatch "y")
{
    Write-Host "Downloading Steam...."
    (New-Object System.Net.WebClient).DownloadFile("https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe", "$WorkingDir\Downloads\SteamSetup.exe")
    Write-Host "Complete!"

    Write-Host "Installing Steam..."
    Start-Process $WorkingDir\Downloads\SteamSetup.exe -ArgumentList "/S" -Wait

    Write-Host "Steam successfully installed!"

    Write-Host ""
}

if($shouldInstallEpicGames -imatch "y")
{
    Write-Host "Downloading Epic Games Launcher...."
    (New-Object System.Net.WebClient).DownloadFile("https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi", "$WorkingDir\Downloads\EpicGamesLauncherInstaller.msi")
    Write-Host "Complete!"

    Write-Host "Installing Epic Games Launcher...."
    msiexec.exe /i $WorkingDir\Downloads\EpicGamesLauncherInstaller.msi /qn
    Write-Host "Epic Games Launcher successfully installed!"
    Write-Host ""
}

if($shouldInstallDiscord -imatch "y")
{
    Write-Host "Downloading Discord...."
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Method Get "https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x86" -OutFile "$WorkingDir\Downloads\DiscordSetup.exe"
    $ProgressPreference = 'Continue'
    Write-Host "Complete!"

    Write-Host "Installing Discord...."
    Start-Process $WorkingDir\Downloads\DiscordSetup.exe -ArgumentList "-s" -Wait
    Write-Host "Discord successfully installed!"

    Write-Host ""
}

Start-Sleep 2

Clear-Host

Write-HostCenter "Drivers"

if($shouldInstallVCRedist -imatch "y")
{
    Write-Host "Downloading Visual C++ for Visual Studio 2015 (x86)...."
    (New-Object System.Net.WebClient).DownloadFile("https://aka.ms/vs/16/release/vc_redist.x86.exe", "$WorkingDir\Downloads\vc_redist.x86.exe")
    Write-Host "Complete!"

    Write-Host "Installing Visual C++ for Visual Studio 2015 (x86)...."
    Start-Process $WorkingDir\Downloads\vc_redist.x86.exe -ArgumentList "/install /quiet /norestart" -Wait
    Write-Host "Visual C++ for Visual Studio 2015 (x86) successfully installed!"
    Write-Host ""

}

if($shouldInstallVBCable -imatch "y")
{
    Write-Host "Downloading VBCable...."
    (New-Object System.Net.WebClient).DownloadFile("https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack43.zip", "$WorkingDir\Downloads\VBCABLE_Driver_Pack43.zip")
    Write-Host "Complete!"

    Write-Host "Installing VBCable...."
    Expand-Archive $WorkingDir\Downloads\VBCABLE_Driver_Pack43.zip -DestinationPath $WorkingDir\Downloads\VBCable 
    Start-Process $WorkingDir\Downloads\VBCable\VBCABLE_Setup_x64.exe -ArgumentList "-i -h" -Wait
    Write-Host "VBCable successfully installed!"
    
    Write-Host ""
}

if($shouldInstallViGEm -imatch "y")
{
    Write-Host "This is still broken, and will be fixed in a future update."
    Write-Host "Installing Xbox 360 Drivers..."
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Method Get "https://drive.google.com/uc?export=download&id=1U9HphlMY8AR3oTZb9p2Y7-jbYcVRJEhp" -OutFile "$WorkingDir\Downloads\Xbox360_64Eng.exe"
    $ProgressPreference = 'Continue'
    Start-Process "$WorkingDir\Downloads\Xbox360_64Eng.exe" -Wait
    Write-Host "Installing ViGEm...."
    (New-Object System.Net.WebClient).DownloadFile("https://github.com/ViGEm/ViGEmBus/releases/download/v1.21.442.0/ViGEmBus_1.21.442_x64_x86_arm64.exe", "$WorkingDir\Downloads\ViGEmBus_1.21.442_x64_x86_arm64.exe")
    Start-Process $WorkingDir\Downloads\ViGEmBus_1.21.442_x64_x86_arm64.exe -ArgumentList "/extract ViGEmBus" -Wait
    Start-Process $WorkingDir\Downloads\5215C05\nefconw.exe -ArgumentList "-remove-device-node --hardware-id Nefarius\ViGEmBus\Gen1 --class-guid 4D36E97D-E325-11CE-BFC1-08002BE10318" -Wait
    Start-Process $WorkingDir\Downloads\5215C05\nefconw.exe -ArgumentList "--remove-device-node --hardware-id Root\ViGEmBus --class-guid 4D36E97D-E325-11CE-BFC1-08002BE10318" -Wait
    Start-Process $WorkingDir\Downloads\5215C05\nefconw.exe -ArgumentList "--create-device-node --hardware-id Nefarius\ViGEmBus\Gen1 --class-name System --class-guid 4D36E97D-E325-11CE-BFC1-08002BE10318" -Wait
    Start-Process $WorkingDir\Downloads\5215C05\nefconw.exe -ArgumentList "--install-driver --inf-path 'ViGEmBus.inf'" -Wait
}

Start-Sleep 2

Clear-Host

Write-HostCenter "Streaming Services"
if($isSupportedSS)
{
    if($prefferedStreamingService -imatch "parsec") {
        Write-Host "Downloading Parsec...."
        (New-Object System.Net.WebClient).DownloadFile("https://builds.parsec.app/package/parsec-windows.exe", "$WorkingDir\Downloads\parsec-windows.exe")
        Write-Host "Complete!"

        Write-Host "Installing Parsec..."
        Start-Process $WorkingDir\Downloads\parsec-windows.exe -ArgumentList '/silent /vdd' -Wait
        Write-Host "Parsec sucessfully installed! You will need to login manually in the app."
    }

    if($prefferedStreamingService -imatch "sunshine") {
        Write-Host "Downloading Sunshine...."
        (New-Object System.Net.WebClient).DownloadFile("https://github.com/LizardByte/Sunshine/releases/download/v0.18.4/sunshine-windows-installer.exe", "$WorkingDir\Downloads\sunshine-windows-installer.exe")
        Write-Host "Complete!"

        Write-Host "Installing Sunshine...."
        Start-Process $WorkingDir\Downloads\sunshine-windows-installer.exe -ArgumentList '/qn' -Wait
        Write-Host "Sunshine successfully installed! Set it up over at https://localhost:49960 when you run it."
    }
}

Set-Service Audiosrv -StartupType Automatic

New-ItemProperty "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DisableCAD" -Value "1" -type String 

net user Administrator $password

if($shouldAutoRestart -imatch "y")
{
    Write-Host "Machine will now restart."
    Start-Sleep 10
    Restart-Computer -Force
} else {
    $shouldRestart = (Read-Host "Should we restart? (y/n)").ToLower()
    if($shouldRestart -imatch "y") {
        Restart-Computer -Force
    }
}
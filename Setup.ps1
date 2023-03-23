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

function isVideoControllerSupported { param($videoController) 
    if($videoController -imatch "NVIDIA Tesla T4")
    {
        return $true
    } 

    return $false
}

Write-HostCenter "Mark's Cloud Gaming Preperation Script!"
Write-Host ""

If (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "You are not admin!"
}

#Try {
#    (Invoke-WebRequest -uri http://169.254.169.254/latest/meta-data/ -TimeoutSec 5)
#    }
#catch {
#    throw "Unsupported cloud provider!"
#}

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
}

if(!$isSupportedSS)
{
    Write-Host "Your service is currently not supported, you will need to install it yourself after!"
}

$shouldInstallChrome = (Read-Host "Should we install Chrome for you? (y/n)").ToLower()

$shouldMakeChromeDefault = (Read-Host "Should we make Chrome default for you? (y/n)").ToLower()

$shouldInstallDrivers = (Read-Host "Should we install drivers for you? (y/n)").ToLower()

if($shouldInstallDrivers -imatch "y") {
    $videoControllerName = (Read-Host "What GPU do you have? (NVIDIA Tesla T4/no)").ToLower()
    $supportedVideoController = isVideoControllerSupported $videoControllerName

    if(!($videoControllerName -imatch "no")) {
        if($shouldInstallDrivers)
        {
            if(!$supportedVideoController)
            {
                $videoControllerName = (Get-CimInstance -ClassName win32_VideoController).name
                $supportedVideoController = isVideoControllerSupported $videoControllerName
                Write-Host $videoControllerName " is currently unsupported! You will need to install drivers on your own."
            }
        }
    }

    $shouldInstallViGEm = (Read-Host "Do you wish to install ViGEm? [For controller passthrough] [BROKEN!] (y/n)").ToLower()
}

$shouldInstallVBCable = (Read-Host "Should we install VBCable for you? [This is for audio transmission!] (y/n)").ToLower()

$shouldInstallSteam = (Read-Host "Should we install Steam for you? (y/n)").ToLower()

$shouldInstallEpicGames = (Read-Host "Should we install Epic Games Launcher for you? (y/n)").ToLower()

$shouldAutoRestart = (Read-Host "Should the script automatically restart for you? (y/n)").ToLower()

$password = (Read-Host "You are required to enter a new password, please enter a new password").ToLower()

if ($supportedVideoController) {
    $AWSACCESSKEY = Read-Host "You are unfortunately required to give an access key and secret key, due to AWS having exclusive drivers. Please input your Access Key"
    $AWSSECRETKEY = Read-Host "Please input your Secret Key"
    Set-AWSCredential -AccessKey $AWSACCESSKEY -SecretKey $AWSSECRETKEY -StoreAs MyNewProfile
    Set-AWSCredential -ProfileName MyNewProfile
}

Write-Host "Please Wait!"
$WorkingDir = (Get-Location).Path.ToString()

If(-not (Test-Path -Path $WorkingDir\Downloads))
{
    New-Item -Path "$WorkingDir\Downloads" -ItemType Directory
}


Clear-Host 

Write-HostCenter "Installation Started!"


if($shouldInstallDrivers -imatch "y")
{
    Write-Host "Installing 7-Zip, this is required for installation!"
    (New-Object System.Net.WebClient).DownloadFile("https://7-zip.org/a/7z2201-x64.msi", "$WorkingDir/Downloads/7z2201-x64.msi")
    msiexec.exe /i $WorkingDir\Downloads\7z2201-x64.msi /qn
    Write-Host "Installing Drivers...."
    .\Steps\InstallDrivers.ps1
    Get-PnpDevice | where {$_.friendlyname -like "Generic Non-PNP Monitor" -and $_.status -eq "OK"} | Disable-PnpDevice -confirm:$false
    Get-PnpDevice | where {$_.friendlyname -like "Microsoft Basic Display Adapter" -and $_.status -eq "OK"} | Disable-PnpDevice -confirm:$false
    Get-PnpDevice | where {$_.friendlyname -like "Google Graphics Array (GGA)" -and $_.status -eq "OK"} | Disable-PnpDevice -confirm:$false
    Get-PnpDevice | where {$_.friendlyname -like "Microsoft Hyper-V Video" -and $_.status -eq "OK"} | Disable-PnpDevice -confirm:$false
}

if($shouldInstallChrome -imatch "y")
{
    Write-Host "Installing Chrome...."
    (New-Object System.Net.WebClient).DownloadFile("https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BADB34C44-5FAF-9B9B-F138-0D6C4BC5BC24%7D%26lang%3Den%26browser%3D3%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1%26installdataindex%3Dempty/chrome/install/ChromeStandaloneSetup64.exe", "$WorkingDir\Downloads\ChromeStandaloneSetup64.exe")
    Start-Process $WorkingDir\Downloads\ChromeStandaloneSetup64.exe -Wait
    Write-Host "Chrome successfully installed!"
}

if($shouldMakeChromeDefault -imatch "y")
{
    Set-DefaultBrowser cr
}

if($shouldInstallSteam -imatch "y")
{
    Write-Host "Installing Steam...."
    (New-Object System.Net.WebClient).DownloadFile("https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe", "$WorkingDir\Downloads\SteamSetup.exe")
    Start-Process $WorkingDir\Downloads\SteamSetup.exe -ArgumentList "/S" -Wait
    Write-Host "Steam successfully installed!"
}

if($shouldInstallEpicGames -imatch "y")
{
    Write-Host "Installing Epic Games...."
    (New-Object System.Net.WebClient).DownloadFile("https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi", "$WorkingDir\Downloads\EpicGamesLauncherInstaller.msi")
    msiexec.exe /i $WorkingDir\Downloads\EpicGamesLauncherInstaller.msi /qn

}

if($shouldInstallVBCable -imatch "y")
{
    Write-Host "Installing VBCable...."
    (New-Object System.Net.WebClient).DownloadFile("https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack43.zip", "$WorkingDir\Downloads\VBCABLE_Driver_Pack43.zip")
    Expand-Archive $WorkingDir\Downloads\VBCABLE_Driver_Pack43.zip -DestinationPath $WorkingDir\Downloads\VBCable 
    Start-Process $WorkingDir\Downloads\VBCable\VBCABLE_Setup_x64.exe -ArgumentList "-i -h" -Wait
}

if($shouldInstallViGEm -imatch "y")
{
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

if($isSupportedSS)
{
    if($prefferedStreamingService -imatch "parsec") {
        Write-Host "Installing Parsec...."
        (New-Object System.Net.WebClient).DownloadFile("https://builds.parsec.app/package/parsec-windows.exe", "$WorkingDir\Downloads\parsec-windows.exe")
        Start-Process $WorkingDir\Downloads\parsec-windows.exe -ArgumentList '/silent /vdd' -Wait
        Write-Host "Parsec sucessfully installed! You will need to login manually in the app."
    }

    if($prefferedStreamingService -imatch "sunshine") {
        Write-Host "Installing Sunshine...."
        (New-Object System.Net.WebClient).DownloadFile("https://github.com/LizardByte/Sunshine/releases/download/v0.18.4/sunshine-windows-installer.exe", "$WorkingDir\Downloads\sunshine-windows-installer.exe")
        Start-Process $WorkingDir\Downloads\sunshine-windows-installer.exe -ArgumentList '/qn' -Wait
        Write-Host "Sunshine successfully installed! Set it up over at https://localhost:49960 when you run it."
    }
}

Set-Service Audiosrv -StartupType Automatic

Set-ItemProperty "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DisableCAD" -Value "1" -type String 

if($shouldAutoLogon -imatch "y")
{
    net user Administrator $password
}

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
# This script will backup web browsers and Mozilla Thunderbird to a specified location from specified users
# If the user is running multiple Thurderbird profiles, they must be backed up manually.
# This script will only back up the most recently used profile

# Define parameters
param (
    [string]$UserName,
    [string]$DestinationPath
)

# Check if specified user exists
function CheckUser {
    $path = "C:\Users\$UserName"
    if (Test-Path -Path $path) {

    } else {
        Write-Host "The specified user directory does not exist."
        exit
    }
}

# Check if destination directory exists
function CheckDestination {
    $path = $DestinationPath
    if (Test-Path -Path $path) {

    } else {
        New-Item -ItemType Directory -Path $path
        Write-Host "Output Directory Created"
    }
}

# Check for Google Chrome profile
function CheckChrome {
    $path = "C:\Users\William\AppData\Local\Google\Chrome\User Data"
        if (Test-Path -Path $path) {
            $Script:chromeInstalled = $true
            Write-Host "Chrome profile found"
        } else {
            $Script:chromeInstalled = $false
            Write-Host "Chrome profile not found"
        }
}

# Check for Microsoft Edge Profile
function CheckEdge {
    $path = "C:\Users\William\AppData\Local\Microsoft\Edge\User Data"
        if (Test-Path -Path $path) {
            $Script:edgeInstalled = $true
            Write-Host "Edge profile found"
        } else {
            $Script:edgeInstalled = $false
            Write-Host "Edge profile not found"
        }
}

# Check for Mozilla Firefox Profile
function CheckFirefox {
    $path = "C:\Users\William\AppData\Roaming\Mozilla\Firefox\Profiles"
        if (Test-Path -Path $path) {
            $Script:firefoxInstalled = $true
            Write-Host "Firefox profile found"
        } else {
            $Script:firefoxInstalled = $false
            Write-Host "Firefox profile not found"
        }
}

# Check for Mozilla Thunderbird Profile
function CheckThunderbird {
    $path = "C:\Users\William\AppData\Roaming\Thunderbird\Profiles"
        if (Test-Path -Path $path) {
            $Script:thunderbirdInstalled = $true
            Write-Host "Thunderbird profile found"
        } else {
            $Script:thunderbirdInstalled = $false
            Write-Host "Thunderbird profile not found"
        }
}

# Backup Chrome profile if not already backed up
function backupChrome {
    If ($chromeInstalled) {
        $path = "$DestinationPath\Google Chrome"
        if (Test-Path -Path $path) {
            Write-Host "Chrome backup already found.  Skipping."
        } else {
            $chrome = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
            if ($chrome) {
              Write-Host "Chrome is running. Closing it..."
              Stop-Process -Name "chrome"
              Write-Host "Chrome closed."
            } else {
              Write-Host "Chrome is not running."
            }
            Write-Host "Backing up Chrome profile..."
            Copy-Item -Path "C:\Users\William\AppData\Local\Google\Chrome\User Data" -Destination "$DestinationPath\Google Chrome" -Recurse
            Write-Host "Backup Complete!"
        }
        Write-Host ""    
    }
}

# Backup Edge profile if not already backed up
function backupEdge {
    If ($edgeInstalled) {
        $path = "$DestinationPath\Microsoft Edge"
        if (Test-Path -Path $path) {
            Write-Host "Edge backup already found.  Skipping."
        } else {
            $edge = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
            if ($edge) {
              Write-Host "Edge is running. Closing it..."
              Stop-Process -Name "msedge"
              Write-Host "Edge closed."
            } else {
              Write-Host "Edge is not running."
            }
            Write-Host "Backing up Edge profile..."
            Copy-Item -Path "C:\Users\William\AppData\Local\Microsoft\Edge\User Data" -Destination "$DestinationPath\Microsoft Edge" -Recurse
            Write-Host "Backup Complete!"
        }
        Write-Host ""    
    }
}

# Get active Firefox profile
function getActiveFirefox {
    $profilesIniPath = Join-Path -Path $env:APPDATA -ChildPath "Mozilla\Firefox\profiles.ini"
    if (Test-Path $profilesIniPath) {
        $content = Get-Content $profilesIniPath
        $defaultProfileLine = $content | Where-Object { $_ -like "Default=*" }
        if ($defaultProfileLine) {
            $defaultProfileValue = $defaultProfileLine.Split("=")[1]
            $profilePathLine = $content | Where-Object { $_ -like "Path=*" -and $_ -like "*$defaultProfileValue*" }
            if ($profilePathLine) {
                $profileFolderName = $profilePathLine.Split("=")[1]
                $activeProfilePath = Join-Path -Path $env:APPDATA -ChildPath "Mozilla\Firefox\$profileFolderName"
                $script:firefoxProfileName = $profileFolderName
                return $activeProfilePath
            } else {
                Write-Host "Could not find the active profile path in profiles.ini"
                exit
            }
        } else {
            Write-Host "Could not find the default profile in profiles.ini"
            exit
        }
    } else {
        Write-Host "profiles.ini file not found at $profilesIniPath"
        exit
    }
}

# Get active Thunderbird profile
function getActiveThunderbird {
    $profilesIniPath = Join-Path -Path $env:APPDATA -ChildPath "Thunderbird\profiles.ini"
    if (Test-Path $profilesIniPath) {
        $content = Get-Content $profilesIniPath
        $defaultProfileLine = $content | Where-Object { $_ -like "Default=*" }
        if ($defaultProfileLine) {
            $defaultProfileValue = $defaultProfileLine.Split("=")[1]
            $profilePathLine = $content | Where-Object { $_ -like "Path=*" -and $_ -like "*$defaultProfileValue*" }
            if ($profilePathLine) {
                $profileFolderName = $profilePathLine.Split("=")[1]
                $activeProfilePath = Join-Path -Path $env:APPDATA -ChildPath "Thunderbird\$profileFolderName"
                $script:thunderbirdProfileName = $profileFolderName
                return $activeProfilePath
            } else {
                Write-Host "Could not find the active profile path in profiles.ini"
                exit
            }
        } else {
            Write-Host "Could not find the default profile in profiles.ini"
            exit
        }
    } else {
        Write-Host "profiles.ini file not found at $profilesIniPath"
        exit
    }
}

# Backup firefox profile if not already backed up
function backupFirefox {
    If ($firefoxInstalled) {
        $firefoxPath = getActiveFirefox
        $path = "$DestinationPath\Firefox\$firefoxProfileName"
        if (Test-Path -Path $path) {
            Write-Host "Firefox backup already found.  Skipping."
        } else {
            $firefox = Get-Process -Name "firefox" -ErrorAction SilentlyContinue
            if ($firefox) {
              Write-Host "Firefox is running. Closing it..."
              Stop-Process -Name "firefox"
              Write-Host "Firefox closed."
            } else {
              Write-Host "Firefox is not running."
            }
            Write-Host "Backing up Firefox profile..."
            #Copy-Item -Path $firefoxPath -Destination "$DestinationPath\Firefox\$firefoxProfileName" -Recurse
            robocopy $firefoxPath "$DestinationPath\Firefox\$firefoxProfileName" /E /njh /njs /ndl /nc /ns /nfl
            Write-Host "Backup Complete!"
        }
        Write-Host ""    
    }
}

# Backup Thundebird profile if not already backed up
function backupThunderbird {
    If ($thunderbirdInstalled) {
        $thunderbirdPath = getActiveThunderbird
        $path = "$DestinationPath\Thunderbird\$thunderbirdProfileName"
        if (Test-Path -Path $path) {
            Write-Host "Thunderbird backup already found.  Skipping."
        } else {
            $thunderbird = Get-Process -Name "thunderbird" -ErrorAction SilentlyContinue
            if ($thunderbird) {
              Write-Host "Thunderbird is running. Closing it..."
              Stop-Process -Name "thunderbird"
              Write-Host "Thunderbird closed."
            } else {
              Write-Host "Thunderbird is not running."
            }
            Write-Host "Backing up thunderbird profile..."
            robocopy $thunderbirdPath "$DestinationPath\Thunderbird\$thunderbirdProfileName" /E /njh /njs /ndl /nc /ns /nfl
            Write-Host "Backup Complete!"
        }
        Write-Host ""    
    }
}

Write-Output ""
Write-Output "Browser Backup Script v1.0"
Write-Output ""


If (($UserName -like $null) -or ($DestinationPath -like $null)) {
    Write-Output 'Command Usage: BrowserBackup.ps1 -UserName "UserToBackup" -DestinationPath "C:\BackupDestination"'
    exit
}

CheckUser
CheckDestination

# Check for Chrome profile
Write-Host ""
Write-Host "Checking for Google Chrome..."
CheckChrome
Write-Host ""

# Check for Edge profile
Write-Host ""
Write-Host "Checking for Microsoft Edge..."
CheckEdge
Write-Host ""

# Check for Firefox profile
Write-Host ""
Write-Host "Checking for Mozilla Firefox..."
CheckFirefox
Write-Host ""

# Check for Thunderbird profile
Write-Host ""
Write-Host "Checking for Mozilla Thunderbird..."
CheckThunderbird
Write-Host ""

Write-Host "Browsers/Email Clients will be closed to backup."
Read-Host -Prompt "Press any key to continue..."

#Backup Chrome
BackupChrome

#Backup Edge
BackupEdge

#Backup Firefox
BackupFirefox

#Backup Thunderbird
BackupThunderbird

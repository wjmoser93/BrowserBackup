# Browser & Email Backup Script with GUI
# Requires Windows PowerShell

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Global Variables & Functions ---
$script:UserName = ""
$script:DestinationPath = ""
$script:chromeInstalled = $false
$script:edgeInstalled = $false
$script:firefoxInstalled = $false
$script:thunderbirdInstalled = $false
$script:firefoxProfileName = ""
$script:thunderbirdProfileName = ""

# Logging function to output to GUI
function Write-Log {
    param([string]$Message)
    if ($outputBox.InvokeRequired) {
        $outputBox.Invoke([action]{ $outputBox.AppendText("$Message`r`n"); $outputBox.ScrollToCaret() })
    } else {
        $outputBox.AppendText("$Message`r`n")
        $outputBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function CheckUser {
    $path = "C:\Users\$script:UserName"
    if (-Not (Test-Path -Path $path)) {
        Write-Log "ERROR: The specified user directory ($path) does not exist."
        return $false
    }
    return $true
}

function CheckDestination {
    $path = $script:DestinationPath
    if (-Not (Test-Path -Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
        Write-Log "Output Directory Created: $path"
    }
}

function CheckChrome {
    $path = "C:\Users\$script:UserName\AppData\Local\Google\Chrome\User Data"
    if (Test-Path -Path $path) {
        $script:chromeInstalled = $true
        Write-Log "Chrome profile found."
    } else {
        $script:chromeInstalled = $false
        Write-Log "Chrome profile not found."
    }
}

function CheckEdge {
    $path = "C:\Users\$script:UserName\AppData\Local\Microsoft\Edge\User Data"
    if (Test-Path -Path $path) {
        $script:edgeInstalled = $true
        Write-Log "Edge profile found."
    } else {
        $script:edgeInstalled = $false
        Write-Log "Edge profile not found."
    }
}

function CheckFirefox {
    $path = "C:\Users\$script:UserName\AppData\Roaming\Mozilla\Firefox\Profiles"
    if (Test-Path -Path $path) {
        $script:firefoxInstalled = $true
        Write-Log "Firefox profile found."
    } else {
        $script:firefoxInstalled = $false
        Write-Log "Firefox profile not found."
    }
}

function CheckThunderbird {
    $path = "C:\Users\$script:UserName\AppData\Roaming\Thunderbird\Profiles"
    if (Test-Path -Path $path) {
        $script:thunderbirdInstalled = $true
        Write-Log "Thunderbird profile found."
    } else {
        $script:thunderbirdInstalled = $false
        Write-Log "Thunderbird profile not found."
    }
}

function getActiveFirefox {
    $profilesIniPath = "C:\Users\$script:UserName\AppData\Roaming\Mozilla\Firefox\profiles.ini"
    if (Test-Path $profilesIniPath) {
        $content = Get-Content $profilesIniPath
        $defaultProfileLine = $content | Where-Object { $_ -like "Default=*" }
        if ($defaultProfileLine) {
            $defaultProfileValue = $defaultProfileLine.Split("=")[1]
            $profilePathLine = $content | Where-Object { $_ -like "Path=*" -and $_ -like "*$defaultProfileValue*" }
            if ($profilePathLine) {
                $profileFolderName = $profilePathLine.Split("=")[1]
                $activeProfilePath = "C:\Users\$script:UserName\AppData\Roaming\Mozilla\Firefox\$profileFolderName"
                $script:firefoxProfileName = $profileFolderName
                return $activeProfilePath
            } else {
                Write-Log "Could not find the active profile path in profiles.ini"
                return $null
            }
        } else {
            Write-Log "Could not find the default profile in profiles.ini"
            return $null
        }
    } else {
        Write-Log "profiles.ini file not found at $profilesIniPath"
        return $null
    }
}

function getActiveThunderbird {
    $profilesIniPath = "C:\Users\$script:UserName\AppData\Roaming\Thunderbird\profiles.ini"
    if (Test-Path $profilesIniPath) {
        $content = Get-Content $profilesIniPath
        $defaultProfileLine = $content | Where-Object { $_ -like "Default=*" }
        if ($defaultProfileLine) {
            $defaultProfileValue = $defaultProfileLine.Split("=")[1]
            $profilePathLine = $content | Where-Object { $_ -like "Path=*" -and $_ -like "*$defaultProfileValue*" }
            if ($profilePathLine) {
                $profileFolderName = $profilePathLine.Split("=")[1]
                $activeProfilePath = "C:\Users\$script:UserName\AppData\Roaming\Thunderbird\$profileFolderName"
                $script:thunderbirdProfileName = $profileFolderName
                return $activeProfilePath
            } else {
                Write-Log "Could not find the active profile path in profiles.ini"
                return $null
            }
        } else {
            Write-Log "Could not find the default profile in profiles.ini"
            return $null
        }
    } else {
        Write-Log "profiles.ini file not found at $profilesIniPath"
        return $null
    }
}

function backupChrome {
    if ($script:chromeInstalled) {
        $path = "$script:DestinationPath\Google Chrome"
        if (Test-Path -Path $path) {
            Write-Log "Chrome backup already found in destination. Skipping."
        } else {
            $chrome = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
            if ($chrome) {
                Write-Log "Chrome is running. Closing it..."
                Stop-Process -Name "chrome" -Force
                Start-Sleep -Seconds 2
                Write-Log "Chrome closed."
            }
            Write-Log "Backing up Chrome profile... (This may take a minute)"
            Copy-Item -Path "C:\Users\$script:UserName\AppData\Local\Google\Chrome\User Data" -Destination "$script:DestinationPath\Google Chrome" -Recurse -Force
            Write-Log "Chrome Backup Complete!"
        }
    }
}

function backupEdge {
    if ($script:edgeInstalled) {
        $path = "$script:DestinationPath\Microsoft Edge"
        if (Test-Path -Path $path) {
            Write-Log "Edge backup already found in destination. Skipping."
        } else {
            $edge = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
            if ($edge) {
                Write-Log "Edge is running. Closing it..."
                Stop-Process -Name "msedge" -Force
                Start-Sleep -Seconds 2
                Write-Log "Edge closed."
            }
            Write-Log "Backing up Edge profile... (This may take a minute)"
            Copy-Item -Path "C:\Users\$script:UserName\AppData\Local\Microsoft\Edge\User Data" -Destination "$script:DestinationPath\Microsoft Edge" -Recurse -Force
            Write-Log "Edge Backup Complete!"
        }
    }
}

function backupFirefox {
    if ($script:firefoxInstalled) {
        $firefoxPath = getActiveFirefox
        if ($null -ne $firefoxPath) {
            $path = "$script:DestinationPath\Firefox\$script:firefoxProfileName"
            if (Test-Path -Path $path) {
                Write-Log "Firefox backup already found in destination. Skipping."
            } else {
                $firefox = Get-Process -Name "firefox" -ErrorAction SilentlyContinue
                if ($firefox) {
                    Write-Log "Firefox is running. Closing it..."
                    Stop-Process -Name "firefox" -Force
                    Start-Sleep -Seconds 2
                    Write-Log "Firefox closed."
                }
                Write-Log "Backing up Firefox profile... (This may take a minute)"
                $roboArgs = @($firefoxPath, "$script:DestinationPath\Firefox\$script:firefoxProfileName", "/E", "/njh", "/njs", "/ndl", "/nc", "/ns", "/nfl")
                & robocopy $roboArgs | Out-Null
                Write-Log "Firefox Backup Complete!"
            }
        }
    }
}

function backupThunderbird {
    if ($script:thunderbirdInstalled) {
        $thunderbirdPath = getActiveThunderbird
        if ($null -ne $thunderbirdPath) {
            $path = "$script:DestinationPath\Thunderbird\$script:thunderbirdProfileName"
            if (Test-Path -Path $path) {
                Write-Log "Thunderbird backup already found in destination. Skipping."
            } else {
                $thunderbird = Get-Process -Name "thunderbird" -ErrorAction SilentlyContinue
                if ($thunderbird) {
                    Write-Log "Thunderbird is running. Closing it..."
                    Stop-Process -Name "thunderbird" -Force
                    Start-Sleep -Seconds 2
                    Write-Log "Thunderbird closed."
                }
                Write-Log "Backing up Thunderbird profile... (This may take a minute)"
                $roboArgs = @($thunderbirdPath, "$script:DestinationPath\Thunderbird\$script:thunderbirdProfileName", "/E", "/njh", "/njs", "/ndl", "/nc", "/ns", "/nfl")
                & robocopy $roboArgs | Out-Null
                Write-Log "Thunderbird Backup Complete!"
            }
        }
    }
}

# --- GUI Construction ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Browser & Thunderbird Backup Utility"
$form.Size = New-Object System.Drawing.Size(520, 500)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$fontBold = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$fontNormal = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

# User Name Label & TextBox
$lblUser = New-Object System.Windows.Forms.Label
$lblUser.Text = "User Profile to Backup (e.g., JDoe):"
$lblUser.Location = New-Object System.Drawing.Point(20, 20)
$lblUser.Size = New-Object System.Drawing.Size(220, 20)
$lblUser.Font = $fontBold
$form.Controls.Add($lblUser)

$txtUser = New-Object System.Windows.Forms.TextBox
$txtUser.Location = New-Object System.Drawing.Point(20, 40)
$txtUser.Size = New-Object System.Drawing.Size(200, 20)
$txtUser.Text = $env:USERNAME # Default to current user
$txtUser.Font = $fontNormal
$form.Controls.Add($txtUser)

# Destination Label, TextBox & Browse Button
$lblDest = New-Object System.Windows.Forms.Label
$lblDest.Text = "Backup Destination:"
$lblDest.Location = New-Object System.Drawing.Point(20, 70)
$lblDest.Size = New-Object System.Drawing.Size(200, 20)
$lblDest.Font = $fontBold
$form.Controls.Add($lblDest)

$txtDest = New-Object System.Windows.Forms.TextBox
$txtDest.Location = New-Object System.Drawing.Point(20, 90)
$txtDest.Size = New-Object System.Drawing.Size(370, 20)
$txtDest.Font = $fontNormal
$form.Controls.Add($txtDest)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(400, 89)
$btnBrowse.Size = New-Object System.Drawing.Size(80, 23)
$btnBrowse.Font = $fontNormal
$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select Backup Destination Folder"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtDest.Text = $dialog.SelectedPath
    }
})
$form.Controls.Add($btnBrowse)

# Group Box for selections
$groupBox = New-Object System.Windows.Forms.GroupBox
$groupBox.Text = "Select items to backup"
$groupBox.Location = New-Object System.Drawing.Point(20, 130)
$groupBox.Size = New-Object System.Drawing.Size(460, 80)
$groupBox.Font = $fontBold
$form.Controls.Add($groupBox)

# Checkboxes
$chkChrome = New-Object System.Windows.Forms.CheckBox
$chkChrome.Text = "Google Chrome"
$chkChrome.Location = New-Object System.Drawing.Point(20, 25)
$chkChrome.Checked = $true
$chkChrome.Font = $fontNormal
$groupBox.Controls.Add($chkChrome)

$chkEdge = New-Object System.Windows.Forms.CheckBox
$chkEdge.Text = "Microsoft Edge"
$chkEdge.Location = New-Object System.Drawing.Point(20, 50)
$chkEdge.Checked = $true
$chkEdge.Font = $fontNormal
$groupBox.Controls.Add($chkEdge)

$chkFirefox = New-Object System.Windows.Forms.CheckBox
$chkFirefox.Text = "Mozilla Firefox"
$chkFirefox.Location = New-Object System.Drawing.Point(200, 25)
$chkFirefox.Checked = $true
$chkFirefox.Font = $fontNormal
$groupBox.Controls.Add($chkFirefox)

$chkThunderbird = New-Object System.Windows.Forms.CheckBox
$chkThunderbird.Text = "Mozilla Thunderbird"
$chkThunderbird.Location = New-Object System.Drawing.Point(200, 50)
$chkThunderbird.Checked = $true
$chkThunderbird.Size = New-Object System.Drawing.Size(150, 20)
$chkThunderbird.Font = $fontNormal
$groupBox.Controls.Add($chkThunderbird)

# Start Button
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start Backup"
$btnStart.Location = New-Object System.Drawing.Point(180, 225)
$btnStart.Size = New-Object System.Drawing.Size(140, 35)
$btnStart.Font = $fontBold
$btnStart.BackColor = [System.Drawing.Color]::LightGreen
$form.Controls.Add($btnStart)

# Output / Log Box
$outputBox = New-Object System.Windows.Forms.RichTextBox
$outputBox.Location = New-Object System.Drawing.Point(20, 275)
$outputBox.Size = New-Object System.Drawing.Size(460, 160)
$outputBox.ReadOnly = $true
$outputBox.ScrollBars = 'Vertical'
$outputBox.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
$form.Controls.Add($outputBox)

# --- Main Logic Event ---
$btnStart.Add_Click({
    $script:UserName = $txtUser.Text.Trim()
    $script:DestinationPath = $txtDest.Text.Trim()

    if ([string]::IsNullOrEmpty($script:UserName)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a User Name.")
        return
    }
    
    if ([string]::IsNullOrEmpty($script:DestinationPath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a Backup Destination.")
        return
    }

    # Ask for confirmation since this will close running browsers
    $confirmMsg = "This process will force close the selected applications if they are running. Do you want to continue?"
    $result = [System.Windows.Forms.MessageBox]::Show($confirmMsg, "Confirm Action", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        $btnStart.Enabled = $false
        $outputBox.Clear()
        Write-Log "--- Starting Backup Process ---"
        
        if (-Not (CheckUser)) { 
            $btnStart.Enabled = $true
            return 
        }
        
        CheckDestination
        
        # Execute checks and backups based on GUI checkboxes
        if ($chkChrome.Checked) {
            Write-Log "`n> Checking Google Chrome..."
            CheckChrome
            backupChrome
        }
        
        if ($chkEdge.Checked) {
            Write-Log "`n> Checking Microsoft Edge..."
            CheckEdge
            backupEdge
        }
        
        if ($chkFirefox.Checked) {
            Write-Log "`n> Checking Mozilla Firefox..."
            CheckFirefox
            backupFirefox
        }
        
        if ($chkThunderbird.Checked) {
            Write-Log "`n> Checking Mozilla Thunderbird..."
            CheckThunderbird
            backupThunderbird
        }

        Write-Log "`n--- All Selected Backups Completed ---"
        [System.Windows.Forms.MessageBox]::Show("Backup tasks have finished!", "Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        $btnStart.Enabled = $true
    }
})

# Show the form
[void]$form.ShowDialog()
# Browser & Email Backup/Restore Script with GUI
# Requires Windows PowerShell

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Global Variables & Functions ---
$script:UserName = ""
$script:LocationPath = "" # Serves as Destination for Backup, Source for Restore
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
        Write-Log "ERROR: The specified local user directory ($path) does not exist."
        Write-Log "Please ensure the user has logged into this PC at least once."
        return $false
    }
    return $true
}

function CheckLocationPath {
    param([bool]$IsBackup)
    $path = $script:LocationPath
    if ($IsBackup) {
        if (-Not (Test-Path -Path $path)) {
            New-Item -ItemType Directory -Path $path | Out-Null
            Write-Log "Output Directory Created: $path"
        }
        return $true
    } else {
        if (-Not (Test-Path -Path $path)) {
            Write-Log "ERROR: Restore source directory ($path) does not exist."
            return $false
        }
        return $true
    }
}

# --- BACKUP FUNCTIONS ---

function getActiveMozillaProfile {
    param([string]$AppName) # "Mozilla\Firefox" or "Thunderbird"
    $profilesIniPath = "C:\Users\$script:UserName\AppData\Roaming\$AppName\profiles.ini"
    if (Test-Path $profilesIniPath) {
        $content = Get-Content $profilesIniPath
        $defaultProfileLine = $content | Where-Object { $_ -like "Default=*" }
        if ($defaultProfileLine) {
            $defaultProfileValue = $defaultProfileLine.Split("=")[1]
            $profilePathLine = $content | Where-Object { $_ -like "Path=*" -and $_ -like "*$defaultProfileValue*" }
            if ($profilePathLine) {
                $profileFolderName = $profilePathLine.Split("=")[1]
                # Replace forward slashes with backslashes just in case
                $profileFolderName = $profileFolderName.Replace("/", "\")
                $activeProfilePath = "C:\Users\$script:UserName\AppData\Roaming\$AppName\$profileFolderName"
                
                # We only need the actual folder name (e.g. 'abcdef.default')
                $folderNameOnly = Split-Path $profileFolderName -Leaf
                return @{ Path = $activeProfilePath; Name = $folderNameOnly }
            }
        }
    }
    return $null
}

function backupApp {
    param([string]$AppName, [string]$ProcessName, [string]$SourcePath, [string]$DestFolder)
    
    if (Test-Path -Path $SourcePath) {
        Write-Log "`n> Checking $AppName... Profile found."
        $path = "$script:LocationPath\$DestFolder"
        if (Test-Path -Path $path) {
            Write-Log "$AppName backup already found in destination. Skipping."
        } else {
            $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Log "$AppName is running. Closing it..."
                Stop-Process -Name $ProcessName -Force
                Start-Sleep -Seconds 2
            }
            Write-Log "Backing up $AppName profile... (This may take a minute)"
            $roboArgs = @($SourcePath, $path, "/E", "/njh", "/njs", "/ndl", "/nc", "/ns", "/nfl")
            & robocopy $roboArgs | Out-Null
            Write-Log "$AppName Backup Complete!"
        }
    } else {
        Write-Log "`n> Checking $AppName... Profile not found."
    }
}

function backupFirefox {
    $profileInfo = getActiveMozillaProfile -AppName "Mozilla\Firefox"
    if ($null -ne $profileInfo) {
        backupApp -AppName "Mozilla Firefox" -ProcessName "firefox" -SourcePath $profileInfo.Path -DestFolder "Firefox\$($profileInfo.Name)"
    } else {
        Write-Log "`n> Checking Mozilla Firefox... Active profile not found."
    }
}

function backupThunderbird {
    $profileInfo = getActiveMozillaProfile -AppName "Thunderbird"
    if ($null -ne $profileInfo) {
        backupApp -AppName "Mozilla Thunderbird" -ProcessName "thunderbird" -SourcePath $profileInfo.Path -DestFolder "Thunderbird\$($profileInfo.Name)"
    } else {
        Write-Log "`n> Checking Mozilla Thunderbird... Active profile not found."
    }
}

# --- RESTORE FUNCTIONS ---

function restoreChromiumApp {
    param([string]$AppName, [string]$ProcessName, [string]$SourceFolder, [string]$DestPath)
    
    $src = "$script:LocationPath\$SourceFolder"
    if (-Not (Test-Path $src)) {
        Write-Log "`n> ${AppName}: No backup found in source folder."
        return
    }

    Write-Log "`n> Restoring $AppName..."
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Log "Closing running instance of $AppName..."
        Stop-Process -Name $ProcessName -Force
        Start-Sleep -Seconds 2
    }

    # Ensure parent directory exists on fresh PC
    if (-Not (Test-Path $DestPath)) {
        New-Item -ItemType Directory -Force -Path $DestPath | Out-Null
    }

    Write-Log "Copying profile data... (This may take a minute)"
    $roboArgs = @($src, $DestPath, "/E", "/njh", "/njs", "/ndl", "/nc", "/ns", "/nfl")
    & robocopy $roboArgs | Out-Null
    Write-Log "$AppName Restore Complete!"
}

function restoreMozillaApp {
    param([string]$AppName, [string]$ProcessName, [string]$SourceFolder, [string]$AppDataRoot)
    
    $srcBase = "$script:LocationPath\$SourceFolder"
    if (-Not (Test-Path $srcBase)) {
        Write-Log "`n> ${AppName}: No backup found in source folder."
        return
    }

    # Find the backed-up profile folder (assume the first folder found inside the backup directory)
    $profiles = Get-ChildItem -Path $srcBase -Directory
    if ($profiles.Count -eq 0) {
        Write-Log "`n> ${AppName}: Backup folder found, but it is empty."
        return
    }
    
    $profileName = $profiles[0].Name
    $src = $profiles[0].FullName
    $dest = "C:\Users\$script:UserName\AppData\Roaming\$AppDataRoot\Profiles\$profileName"
    
    Write-Log "`n> Restoring $AppName..."
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Log "Closing running instance of $AppName..."
        Stop-Process -Name $ProcessName -Force
        Start-Sleep -Seconds 2
    }

    # Create directory tree for fresh install
    if (-Not (Test-Path $dest)) {
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
    }

    Write-Log "Copying profile data... (This may take a minute)"
    $roboArgs = @($src, $dest, "/E", "/njh", "/njs", "/ndl", "/nc", "/ns", "/nfl")
    & robocopy $roboArgs | Out-Null

    # Rebuild profiles.ini so the app finds it on a fresh install
    Write-Log "Rebuilding profiles.ini..."
    $iniPath = "C:\Users\$script:UserName\AppData\Roaming\$AppDataRoot\profiles.ini"
    $iniContent = @"
[Profile0]
Name=default
IsRelative=1
Path=Profiles/$profileName
Default=1

[General]
StartWithLastProfile=1
"@
    Set-Content -Path $iniPath -Value $iniContent -Force
    Write-Log "$AppName Restore Complete!"
}


# --- GUI Construction ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "Browser & Thunderbird Backup/Restore Utility"
$form.Size = New-Object System.Drawing.Size(520, 560)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$fontBold = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$fontNormal = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

# Mode Selection
$grpMode = New-Object System.Windows.Forms.GroupBox
$grpMode.Text = "Operation Mode"
$grpMode.Location = New-Object System.Drawing.Point(20, 10)
$grpMode.Size = New-Object System.Drawing.Size(460, 50)
$grpMode.Font = $fontBold
$form.Controls.Add($grpMode)

$rdoBackup = New-Object System.Windows.Forms.RadioButton
$rdoBackup.Text = "Backup Profiles"
$rdoBackup.Location = New-Object System.Drawing.Point(80, 20)
$rdoBackup.Checked = $true
$rdoBackup.Font = $fontNormal
$grpMode.Controls.Add($rdoBackup)

$rdoRestore = New-Object System.Windows.Forms.RadioButton
$rdoRestore.Text = "Restore Profiles to PC"
$rdoRestore.Location = New-Object System.Drawing.Point(250, 20)
$rdoRestore.Font = $fontNormal
$grpMode.Controls.Add($rdoRestore)

# User Name Label & TextBox
$lblUser = New-Object System.Windows.Forms.Label
$lblUser.Text = "Local User Profile (e.g., JDoe):"
$lblUser.Location = New-Object System.Drawing.Point(20, 75)
$lblUser.Size = New-Object System.Drawing.Size(220, 20)
$lblUser.Font = $fontBold
$form.Controls.Add($lblUser)

$txtUser = New-Object System.Windows.Forms.TextBox
$txtUser.Location = New-Object System.Drawing.Point(20, 95)
$txtUser.Size = New-Object System.Drawing.Size(200, 20)
$txtUser.Text = $env:USERNAME
$txtUser.Font = $fontNormal
$form.Controls.Add($txtUser)

# Destination/Source Label, TextBox & Browse Button
$lblLocation = New-Object System.Windows.Forms.Label
$lblLocation.Text = "Backup Destination Directory:"
$lblLocation.Location = New-Object System.Drawing.Point(20, 125)
$lblLocation.Size = New-Object System.Drawing.Size(300, 20)
$lblLocation.Font = $fontBold
$form.Controls.Add($lblLocation)

$txtLocation = New-Object System.Windows.Forms.TextBox
$txtLocation.Location = New-Object System.Drawing.Point(20, 145)
$txtLocation.Size = New-Object System.Drawing.Size(370, 20)
$txtLocation.Font = $fontNormal
$form.Controls.Add($txtLocation)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(400, 144)
$btnBrowse.Size = New-Object System.Drawing.Size(80, 24)
$btnBrowse.Font = $fontNormal
$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select Folder"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtLocation.Text = $dialog.SelectedPath
    }
})
$form.Controls.Add($btnBrowse)

# Group Box for selections
$groupBox = New-Object System.Windows.Forms.GroupBox
$groupBox.Text = "Select items to process"
$groupBox.Location = New-Object System.Drawing.Point(20, 185)
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
$btnStart.Location = New-Object System.Drawing.Point(180, 280)
$btnStart.Size = New-Object System.Drawing.Size(140, 35)
$btnStart.Font = $fontBold
$btnStart.BackColor = [System.Drawing.Color]::LightGreen
$form.Controls.Add($btnStart)

# Output / Log Box
$outputBox = New-Object System.Windows.Forms.RichTextBox
$outputBox.Location = New-Object System.Drawing.Point(20, 330)
$outputBox.Size = New-Object System.Drawing.Size(460, 170)
$outputBox.ReadOnly = $true
$outputBox.ScrollBars = 'Vertical'
$outputBox.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
$form.Controls.Add($outputBox)

# --- Event Handlers for Mode Switch ---
$rdoRestore.Add_CheckedChanged({
    if ($rdoRestore.Checked) {
        $lblLocation.Text = "Restore Source Directory:"
        $btnStart.Text = "Start Restore"
        $btnStart.BackColor = [System.Drawing.Color]::LightSkyBlue
    } else {
        $lblLocation.Text = "Backup Destination Directory:"
        $btnStart.Text = "Start Backup"
        $btnStart.BackColor = [System.Drawing.Color]::LightGreen
    }
})

# --- Main Logic Event ---
$btnStart.Add_Click({
    $script:UserName = $txtUser.Text.Trim()
    $script:LocationPath = $txtLocation.Text.Trim()
    $isBackup = $rdoBackup.Checked

    if ([string]::IsNullOrEmpty($script:UserName)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a User Name.")
        return
    }
    
    if ([string]::IsNullOrEmpty($script:LocationPath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a Directory Location.")
        return
    }

    $actionName = if ($isBackup) { "backup" } else { "restore" }
    $confirmMsg = "This process will force close the selected applications if they are running. Do you want to continue with the $actionName?"
    $result = [System.Windows.Forms.MessageBox]::Show($confirmMsg, "Confirm Action", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        $btnStart.Enabled = $false
        $outputBox.Clear()
        Write-Log "--- Starting $($actionName.ToUpper()) Process ---"
        
        if (-Not (CheckUser)) { $btnStart.Enabled = $true; return }
        if (-Not (CheckLocationPath -IsBackup $isBackup)) { $btnStart.Enabled = $true; return }
        
        # Execute BACKUP
        if ($isBackup) {
            if ($chkChrome.Checked) { backupApp -AppName "Google Chrome" -ProcessName "chrome" -SourcePath "C:\Users\$script:UserName\AppData\Local\Google\Chrome\User Data" -DestFolder "Google Chrome" }
            if ($chkEdge.Checked) { backupApp -AppName "Microsoft Edge" -ProcessName "msedge" -SourcePath "C:\Users\$script:UserName\AppData\Local\Microsoft\Edge\User Data" -DestFolder "Microsoft Edge" }
            if ($chkFirefox.Checked) { backupFirefox }
            if ($chkThunderbird.Checked) { backupThunderbird }
        } 
        # Execute RESTORE
        else {
            if ($chkChrome.Checked) { restoreChromiumApp -AppName "Google Chrome" -ProcessName "chrome" -SourceFolder "Google Chrome" -DestPath "C:\Users\$script:UserName\AppData\Local\Google\Chrome\User Data" }
            if ($chkEdge.Checked) { restoreChromiumApp -AppName "Microsoft Edge" -ProcessName "msedge" -SourceFolder "Microsoft Edge" -DestPath "C:\Users\$script:UserName\AppData\Local\Microsoft\Edge\User Data" }
            if ($chkFirefox.Checked) { restoreMozillaApp -AppName "Mozilla Firefox" -ProcessName "firefox" -SourceFolder "Firefox" -AppDataRoot "Mozilla\Firefox" }
            if ($chkThunderbird.Checked) { restoreMozillaApp -AppName "Mozilla Thunderbird" -ProcessName "thunderbird" -SourceFolder "Thunderbird" -AppDataRoot "Thunderbird" }
        }

        Write-Log "`n--- All Selected Tasks Completed ---"
        [System.Windows.Forms.MessageBox]::Show("Tasks have finished!", "Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        $btnStart.Enabled = $true
    }
})

# Show the form
[void]$form.ShowDialog()
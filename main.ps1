# August 2021
# Created by and Patrix87 of https://bucherons.ca
# Run this script to Stop->Backup->Update->Start your server.

[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)]
  [string]$ServerCfg
)

#---------------------------------------------------------
# Importing functions and variables.
#---------------------------------------------------------

# import global config, all functions. Exit if fails.
try {
  Import-Module -Name ".\global.psm1"
  Get-ChildItem -Path ".\functions" -Include "*.psm1" -Recurse | Import-Module
}
catch {
  Exit-WithError -ErrorMsg "Unable to import modules."
  Exit
}

#---------------------------------------------------------
# Start Logging
#---------------------------------------------------------

#Define Logfile by TimeStamp-ServerCfg.
$LogFile = "$($Global.LogFolder)\$(Get-TimeStamp)-$($ServerCfg).txt"
# Start Logging
Start-Transcript -Path $LogFile -IncludeInvocationHeader
if($Global.Debug) {
  [Console]::ForegroundColor = $Global.ErrorColor
  [Console]::BackgroundColor = $Global.ErrorBgColor
  Write-Host "DEBUG MODE ENABLED"
  [Console]::ResetColor()
}
$NoLogs = $false

#---------------------------------------------------------
# Set Script Directory as Working Directory
#---------------------------------------------------------

#Find the location of the current invocation of main.ps1, remove the filename, set the working directory to that path.
Write-ScriptMsg "Setting Script Directory as Working Directory..."
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path -Path $scriptpath
$dir = Resolve-Path -Path $dir
$null = Set-Location -Path $dir
Write-ScriptMsg "Working Directory : $(Get-Location)"

#---------------------------------------------------------
# Get server IPs
#---------------------------------------------------------

Set-IP

#---------------------------------------------------------
# Install Dependencies
#---------------------------------------------------------

Install-Dependency

#---------------------------------------------------------
# Importing server configuration.
#---------------------------------------------------------

Write-ScriptMsg "Importing Server Configuration..."
#Check if requested config exist in the config folder, if not, copy it from the templates. Exit if fails.
if (-not (Test-Path -Path ".\configs\$ServerCfg.psm1" -PathType "Leaf" -ErrorAction SilentlyContinue)) {
  if (Test-Path -Path ".\templates\$ServerCfg.psm1" -PathType "Leaf" -ErrorAction SilentlyContinue) {
    $null = Copy-Item -Path ".\templates\$ServerCfg.psm1" -Destination ".\configs\$ServerCfg.psm1" -ErrorAction SilentlyContinue
  }
  else {
    Exit-WithError -ErrorMsg "Unable to find configuration file."
  }
}

# import the current server config file. Exit if fails.
try {
  Import-Module -Name ".\configs\$ServerCfg.psm1"
}
catch {
  Exit-WithError -ErrorMsg "Unable to import server configuration."
}

#Parse configuration
Read-Config

#Check if script is already running
if (Get-Lock) {
  Write-ScriptMsg "Process is locked, exiting."
  Exit
}

#Locking Script to avoid double run
$null = Lock-Process

#---------------------------------------------------------
# Install Server
#---------------------------------------------------------

Write-ScriptMsg "Verifying Server installation..."
#Flag of a fresh installation in the current instance.
$FreshInstall = $false
#If the server executable is missing, run SteamCMD and install the server.
if (-not (Test-Path -Path $Server.Exec -ErrorAction SilentlyContinue)) {
  Write-ServerMsg "Server is not installed : Installing $($Server.Name) Server."
  Update-Server -UpdateType "Installing"
  Write-ServerMsg "Server successfully installed."
  $FreshInstall = $true
}

#---------------------------------------------------------
# Stop existing server watcher if running
#---------------------------------------------------------
$WatcherPidFile = ".\servers\$($Server.Name)_ServerWatcher.PID"
if (Test-Path $WatcherPidFile) {
  $WatcherPid = Get-Content $WatcherPidFile -ErrorAction SilentlyContinue
  if ($WatcherPid) {
    Write-ScriptMsg "Stopping existing server watcher (PID: $WatcherPid)..."
    Stop-Process -Id $WatcherPid -Force -ErrorAction SilentlyContinue
  }
  Remove-Item $WatcherPidFile -Force -ErrorAction SilentlyContinue
}

#---------------------------------------------------------
# If Server is running warn players then stop server
#---------------------------------------------------------
Write-ScriptMsg "Verifying Server State..."
#If the server is not freshly installed.
if (-not $FreshInstall) {
  Stop-Server
}

#---------------------------------------------------------
# Backup
#---------------------------------------------------------

#If not a fresh install and Backups are enabled, run backups.
if ($Backups.Use -and -not $FreshInstall) {
  Write-ScriptMsg "Verifying Backups..."
  Backup-Server
}
else {
  Write-ScriptMsg "Backups are disabled or this is a fresh installation."
}

#---------------------------------------------------------
# Update
#---------------------------------------------------------

#If not a fresh install, update and/or validate server.
if (-not $FreshInstall -and $Server.AutoUpdates) {
  Write-ScriptMsg "Updating Server..."
  Update-Server -UpdateType "Updating"
  Write-ServerMsg "Server successfully updated and/or validated."
}

#---------------------------------------------------------
# Start Server
#---------------------------------------------------------

#Try to start the server, then if it's stable, set the priority and affinity then register the PID. Exit with Error if it fails.
Start-Server

#---------------------------------------------------------
# Start Server Watcher
#---------------------------------------------------------

# Clean up any stale graceful stop signal
$SignalFile = ".\servers\$($Server.Name)_GracefulStop.signal"
if (Test-Path $SignalFile) {
  Remove-Item $SignalFile -Force -ErrorAction SilentlyContinue
}

# Start watcher if any automation feature is enabled (or if user wants interactive controls)
$hasAutoModUpdates = $Server.PSObject.Properties.Name -contains "AutoModUpdates" -and $Server.AutoModUpdates
$hasWorkshopItems = $Server.PSObject.Properties.Name -contains "WorkshopItems" -and -not [string]::IsNullOrEmpty($Server.WorkshopItems)
if (($Server.AutoRestartOnCrash -or $Server.AutoUpdates -or $Server.AutoRestart -or ($hasAutoModUpdates -and $hasWorkshopItems)) -and -not $FreshInstall) {
  $WatcherScript = Join-Path $dir "server-watcher.ps1"
  if (Test-Path $WatcherScript) {
    # Run visible so user can interact with keyboard controls
    $WatcherProc = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$WatcherScript`" -ServerCfg `"$ServerCfg`"" -PassThru
    Write-ScriptMsg "Server watcher started (PID: $($WatcherProc.Id))"
  }
}

#---------------------------------------------------------
# Open FreshInstall Configuration folder
#---------------------------------------------------------

if ($FreshInstall -and (Test-Path -Path $Server.ConfigFolder -PathType "Container" -ErrorAction SilentlyContinue)) {
  Write-Warning -Message "Stopping the Server to let you edit the configurations files."
  #Stop Server because configuration is probably bad anyway
  Stop-Server
  $null = Unlock-Process
  & explorer.exe $Server.ConfigFolder
  Write-Warning -Message "Launch again when the server configurations files are edited."
  Read-Host "Press Enter to close this windows."
}

#---------------------------------------------------------
# Cleanup
#---------------------------------------------------------

#Remove old log files.
try {
  Write-ScriptMsg "Deleting logs older than $($Global.Days) days."
  Remove-OldLog
}
catch {
  Exit-WithError -ErrorMsg "Unable clean old logs."
}


#---------------------------------------------------------
# Unlock Process
#---------------------------------------------------------

$null = Unlock-Process

Write-ServerMsg "Script successfully completed."

#---------------------------------------------------------
# Stop Logging
#---------------------------------------------------------

$null = Stop-Transcript
if ($NoLogs -and -not ($Global.Debug)) {
  $null = Remove-Item -Path $LogFile -Force -ErrorAction SilentlyContinue
}

# Server Watcher - Interactive monitoring console for game servers
# Provides keyboard controls for admin tasks and automatic crash recovery
# Handles: Alive Check, Update Check, AutoRestart, Mod Update Check, and manual commands

[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)]
  [string]$ServerCfg
)

#---------------------------------------------------------
# Importing functions and variables.
#---------------------------------------------------------

try {
  Import-Module -Name ".\global.psm1"
  Get-ChildItem -Path ".\functions" -Include "*.psm1" -Recurse | Import-Module
}
catch {
  Write-Host "Server Watcher: Unable to import modules, exiting."
  Exit 1
}

#---------------------------------------------------------
# Set Script Directory as Working Directory
#---------------------------------------------------------

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path -Path $scriptpath
Set-Location -Path $dir

#---------------------------------------------------------
# Import Server Config
#---------------------------------------------------------

try {
  Read-Config
}
catch {
  Write-Host "Server Watcher: Unable to read config for $ServerCfg, exiting."
  Exit 1
}

#---------------------------------------------------------
# Validate Configuration
#---------------------------------------------------------

# Check if any automation feature is enabled
$hasAutoModUpdates = $Server.PSObject.Properties.Name -contains "AutoModUpdates" -and $Server.AutoModUpdates
$hasWorkshopItems = $Server.PSObject.Properties.Name -contains "WorkshopItems" -and -not [string]::IsNullOrEmpty($Server.WorkshopItems)

#---------------------------------------------------------
# Store PID for management
#---------------------------------------------------------

$PidFile = ".\servers\$($Server.Name)_ServerWatcher.PID"
$PID | Out-File -FilePath $PidFile -Force

#---------------------------------------------------------
# Start Logging
#---------------------------------------------------------

$LogFile = "$($Global.LogFolder)\server-watcher-$($Server.Name).txt"
Start-Transcript -Path $LogFile -Append

#---------------------------------------------------------
# Initialize State
#---------------------------------------------------------

$script:GracefulStop = $false
$script:LastMessage = ""
$script:MessageTime = $null

$now = Get-Date

# Update check - delay first check to give server time to stabilize
$script:NextUpdateCheck = $now.AddMinutes($Global.UpdateCheckFrequency)

# Mod update check - delay first check
$script:NextModCheck = $now.AddMinutes($Global.ModCheckFrequency)

# AutoRestart - calculate next restart time
function Get-NextRestartTime {
  $now = Get-Date
  $restartHour = $Server.AutoRestartTime[0]
  $restartMinute = $Server.AutoRestartTime[1]
  $restartSecond = $Server.AutoRestartTime[2]

  # Create today's restart time
  $todayRestart = Get-Date -Hour $restartHour -Minute $restartMinute -Second $restartSecond

  if ($now -lt $todayRestart) {
    return $todayRestart
  }
  else {
    return $todayRestart.AddDays(1)
  }
}

$script:NextRestart = if ($Server.AutoRestart) { Get-NextRestartTime } else { $null }

#---------------------------------------------------------
# Display Functions
#---------------------------------------------------------

function Show-Message {
  param ([string]$Message)
  $script:LastMessage = $Message
  $script:MessageTime = Get-Date
}

function Show-Status {
  Clear-Host

  # Header
  Write-Host "+" + ("-" * 60) + "+" -ForegroundColor Cyan
  Write-Host "|  SERVER WATCHER - $($Server.Name.PadRight(41))|" -ForegroundColor Cyan
  Write-Host "+" + ("-" * 60) + "+" -ForegroundColor Cyan

  # Server status
  $proc = Get-ServerProcess
  if ($proc) {
    $status = "RUNNING (PID: $($proc.Id))"
    Write-Host "|  Server Status: " -NoNewline -ForegroundColor White
    Write-Host $status.PadRight(43) -NoNewline -ForegroundColor Green
    Write-Host "|" -ForegroundColor Cyan
  }
  else {
    Write-Host "|  Server Status: " -NoNewline -ForegroundColor White
    Write-Host "STOPPED".PadRight(43) -NoNewline -ForegroundColor Red
    Write-Host "|" -ForegroundColor Cyan
  }

  Write-Host "+" + ("-" * 60) + "+" -ForegroundColor Cyan

  # Monitoring info
  if ($Server.AutoUpdates) {
    $updateIn = [math]::Max(0, [math]::Round(($script:NextUpdateCheck - (Get-Date)).TotalMinutes))
    Write-Host "|  Next Update Check: $($updateIn.ToString().PadRight(3)) minutes".PadRight(61) -NoNewline -ForegroundColor White
    Write-Host "|" -ForegroundColor Cyan
  }

  if ($hasAutoModUpdates -and $hasWorkshopItems) {
    $modIn = [math]::Max(0, [math]::Round(($script:NextModCheck - (Get-Date)).TotalMinutes))
    Write-Host "|  Next Mod Check: $($modIn.ToString().PadRight(3)) minutes".PadRight(61) -NoNewline -ForegroundColor White
    Write-Host "|" -ForegroundColor Cyan
  }

  if ($script:NextRestart) {
    Write-Host "|  Scheduled Restart: $($script:NextRestart.ToString('HH:mm:ss'))".PadRight(61) -NoNewline -ForegroundColor White
    Write-Host "|" -ForegroundColor Cyan
  }

  if ($Server.AutoRestartOnCrash) {
    Write-Host "|  Crash Recovery: ENABLED".PadRight(61) -NoNewline -ForegroundColor White
    Write-Host "|" -ForegroundColor Cyan
  }

  Write-Host "+" + ("-" * 60) + "+" -ForegroundColor Cyan

  # Controls
  Write-Host "|  " -NoNewline -ForegroundColor Cyan
  Write-Host "[S]" -NoNewline -ForegroundColor Yellow
  Write-Host " Save    " -NoNewline -ForegroundColor White
  Write-Host "[Q]" -NoNewline -ForegroundColor Yellow
  Write-Host " Save & Quit    " -NoNewline -ForegroundColor White
  Write-Host "[R]" -NoNewline -ForegroundColor Yellow
  Write-Host " Restart             " -NoNewline -ForegroundColor White
  Write-Host "|" -ForegroundColor Cyan

  Write-Host "|  " -NoNewline -ForegroundColor Cyan
  Write-Host "[U]" -NoNewline -ForegroundColor Yellow
  Write-Host " Update  " -NoNewline -ForegroundColor White
  Write-Host "[M]" -NoNewline -ForegroundColor Yellow
  Write-Host " Check Mods     " -NoNewline -ForegroundColor White
  Write-Host "[X]" -NoNewline -ForegroundColor Yellow
  Write-Host " Exit Watcher        " -NoNewline -ForegroundColor White
  Write-Host "|" -ForegroundColor Cyan

  Write-Host "+" + ("-" * 60) + "+" -ForegroundColor Cyan

  # Message area
  if ($script:LastMessage -and $script:MessageTime) {
    $elapsed = ((Get-Date) - $script:MessageTime).TotalSeconds
    if ($elapsed -lt 10) {
      Write-Host ""
      Write-Host "  $($script:LastMessage)" -ForegroundColor Yellow
    }
  }
}

#---------------------------------------------------------
# Helper function to trigger restart
#---------------------------------------------------------

function Invoke-ServerRestart {
  param (
    [string]$Reason
  )

  Write-Host ""
  Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Reason - triggering server restart..." -ForegroundColor Magenta

  # Invoke main.ps1 to handle the full restart cycle
  $MainScript = Join-Path $dir "main.ps1"
  Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$MainScript`" -ServerCfg `"$ServerCfg`""

  Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Restart triggered, watcher exiting." -ForegroundColor Magenta
  Start-Sleep -Seconds 2
  Exit 0
}

#---------------------------------------------------------
# Keyboard Handler
#---------------------------------------------------------

function Handle-KeyPress {
  param ([char]$Key)

  switch ($Key.ToString().ToUpper()) {
    'S' {
      # Save game
      if ($Warnings.Use) {
        Show-Message "Sending save command..."
        $result = Send-Command $Warnings.CmdSave
        if ($result) {
          Show-Message "Save command sent successfully."
        }
        else {
          Show-Message "Failed to send save command (RCON error)."
        }
      }
      else {
        Show-Message "Cannot save: No remote management configured."
      }
    }
    'Q' {
      # Save and quit gracefully
      if ($Warnings.Use) {
        Show-Message "Saving and quitting..."

        # Create graceful stop signal
        $SignalFile = ".\servers\$($Server.Name)_GracefulStop.signal"
        "Graceful stop initiated at $(Get-Date)" | Out-File -FilePath $SignalFile -Force

        # Send save command
        Send-Command $Warnings.CmdSave
        Start-Sleep -Seconds $Warnings.SaveDelay

        # Send stop command
        Send-Command $Warnings.CmdStop

        $script:GracefulStop = $true
        Show-Message "Quit command sent. Waiting for server to stop..."
      }
      else {
        # No RCON - just set flag and let user know
        Show-Message "No RCON configured. Use server console to quit, or press X to exit watcher."
        $script:GracefulStop = $true
      }
    }
    'R' {
      # Trigger restart
      Invoke-ServerRestart -Reason "Manual restart requested"
    }
    'U' {
      # Force update check (always available for manual check)
      Show-Message "Checking for updates..."
      if (Request-Update) {
        Show-Message "Update available! Press R to restart and apply."
      }
      else {
        Show-Message "No updates available."
      }
      # Reset auto-check timer if enabled
      if ($Server.AutoUpdates) {
        $script:NextUpdateCheck = (Get-Date).AddMinutes($Global.UpdateCheckFrequency)
      }
    }
    'M' {
      # Force mod check (requires WorkshopItems to be configured)
      if ($hasWorkshopItems) {
        Show-Message "Checking workshop mods..."
        if (Request-ModUpdate) {
          Show-Message "Mod updates detected! Press R to restart and apply."
        }
        else {
          Show-Message "No mod updates detected."
        }
        # Reset auto-check timer if enabled
        if ($hasAutoModUpdates) {
          $script:NextModCheck = (Get-Date).AddMinutes($Global.ModCheckFrequency)
        }
      }
      else {
        Show-Message "No WorkshopItems configured in server config."
      }
    }
    'X' {
      # Exit watcher only
      Write-Host ""
      Write-Host "Exiting watcher (server will keep running, no crash protection)..." -ForegroundColor Yellow
      Start-Sleep -Seconds 2
      Exit 0
    }
  }
}

#---------------------------------------------------------
# Main Loop
#---------------------------------------------------------

$lastRefresh = Get-Date
Show-Status

try {
  while ($true) {
    # Check for keypress (non-blocking)
    if ([Console]::KeyAvailable) {
      $key = [Console]::ReadKey($true)
      Handle-KeyPress -Key $key.KeyChar
      Show-Status
    }

    # Refresh display every 5 seconds
    if ((Get-Date) - $lastRefresh -gt [TimeSpan]::FromSeconds(5)) {
      Show-Status
      $lastRefresh = Get-Date
    }

    $now = Get-Date

    # 1. ALIVE CHECK (if AutoRestartOnCrash enabled)
    if ($Server.AutoRestartOnCrash) {
      if (-not (Get-ServerProcess)) {
        # Check for graceful stop signal
        $SignalFile = ".\servers\$($Server.Name)_GracefulStop.signal"
        if ((Test-Path $SignalFile) -or $script:GracefulStop) {
          Write-Host ""
          Write-Host "Server stopped gracefully. Watcher exiting." -ForegroundColor Green
          Remove-Item $SignalFile -Force -ErrorAction SilentlyContinue
          Start-Sleep -Seconds 3
          Exit 0
        }
        else {
          Invoke-ServerRestart -Reason "Server crashed (process not found)"
        }
      }
    }

    # 2. UPDATE CHECK (every UpdateCheckFrequency minutes if AutoUpdates)
    if ($Server.AutoUpdates -and $now -ge $script:NextUpdateCheck) {
      Show-Message "Checking for server updates..."
      Show-Status

      if (Request-Update) {
        Invoke-ServerRestart -Reason "Server update available"
      }
      else {
        Show-Message "No updates available."
      }

      $script:NextUpdateCheck = $now.AddMinutes($Global.UpdateCheckFrequency)
    }

    # 3. AUTO RESTART CHECK (daily at AutoRestartTime if AutoRestart)
    if ($Server.AutoRestart -and $script:NextRestart -and $now -ge $script:NextRestart) {
      $script:NextRestart = Get-NextRestartTime
      Invoke-ServerRestart -Reason "Scheduled daily restart"
    }

    # 4. MOD UPDATE CHECK (every ModCheckFrequency minutes if AutoModUpdates + WorkshopItems)
    if ($hasAutoModUpdates -and $hasWorkshopItems -and $now -ge $script:NextModCheck) {
      Show-Message "Checking for mod updates..."
      Show-Status

      if (Request-ModUpdate) {
        Invoke-ServerRestart -Reason "Workshop mod update detected"
      }
      else {
        Show-Message "No mod updates detected."
      }

      $script:NextModCheck = $now.AddMinutes($Global.ModCheckFrequency)
    }

    # Small delay to prevent CPU spin
    Start-Sleep -Milliseconds 100
  }
}
finally {
  # Cleanup
  if (Test-Path $PidFile) {
    Remove-Item -Path $PidFile -Force -ErrorAction SilentlyContinue
  }
  Stop-Transcript
}

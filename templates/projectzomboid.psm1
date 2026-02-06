<#
#---------------------------------------------------------
# PROJECT ZOMBOID SERVER CONFIGURATION
#---------------------------------------------------------
# This template configures a Project Zomboid dedicated server
#
# FIRST-TIME SETUP (Three-Phase Launch):
#   1. Run launcher → Server installs and creates default configs
#   2. Stop the server (it will create servertest.ini and other config files)
#   3. Launcher generates _template.ini reference files from your .psm1 settings
#   4. You manually review _template files and copy desired settings to actual configs
#   5. Run launcher AGAIN → Server starts with your customized settings
#
# UPDATING SETTINGS:
#   - Edit this .psm1 file to change your desired server configuration
#   - Run launcher → _template files regenerate automatically
#   - Copy new settings from _template to actual .ini files
#   - Restart server
#
# IMPORTANT:
#   - _template.ini files are REFERENCE ONLY (read-only examples)
#   - Actual game configs (servertest.ini, SandboxVars.lua) are NEVER modified by PowerShell
#   - You have full control over game configuration files
#
# IMPORTANT SETTINGS TO CONFIGURE:
#   - JavaHeapMin/Max: Adjust based on player count (see recommendations below)
#   - PublicName: Your server's display name in the browser
#   - Password: Set for private server, leave empty for public
#   - MaxPlayers: Player limit (consider performance with JavaHeap setting)
#   - Mods/WorkshopItems: See examples below for Steam Workshop integration
#
# PORT FORWARDING REQUIRED:
#   Forward GamePort (default 16261), SteamPort1 (8766), SteamPort2 (8767)
#   Protocol: Both TCP and UDP for all three ports
#
# For detailed documentation, see CLAUDE.md in the main folder
#>

#Server Name - This will be the folder name and internal identifier
# For public server browser name, configure PublicName below
$Name = $ServerCfg

#---------------------------------------------------------
# Server Configuration
#---------------------------------------------------------

$ServerDetails = @{

  #Login username used by SteamCMD
  Login              = "anonymous"

  #Rcon IP, usually localhost
  ManagementIP       = "127.0.0.1"

  #Rcon Port in servertest.ini
  ManagementPort     = 27015

  #Rcon Password as set in servertest.ini (Do not use " " in servertest.ini)
  ManagementPassword = "CHANGEME"

  #---------------------------------------------------------
  # Project Zomboid Specific Settings
  #---------------------------------------------------------

  #Server name in Project Zomboid (config file prefix, e.g., "servertest" creates servertest.ini)
  #Change this to your desired server name (used for config file naming)
  ServerName         = "servertest"

  #---------------------------------------------------------
  # Java Configuration
  #---------------------------------------------------------
  # Project Zomboid is a Java application requiring heap memory allocation
  # WARNING: Setting too high may crash the server if system RAM is insufficient
  #
  # RECOMMENDED VALUES:
  #   2-4 GB:  Up to 10 players, light mods
  #   6-8 GB:  10-20 players, moderate mods
  #  12-16 GB: 20+ players, heavy mods, large maps
  #
  # IMPORTANT: JavaHeapMin and JavaHeapMax should be equal for stability
  # Example: For 10 players with mods, use 6 and 6
  JavaHeapMin          = 6   # Initial heap size (in GB)
  JavaHeapMax          = 6   # Maximum heap size (in GB, should equal JavaHeapMin)

  #---------------------------------------------------------
  # Server Ports
  #---------------------------------------------------------
  # These must be forwarded in your router (both TCP and UDP)
  GamePort             = 16261  # Main game port
  SteamPort1           = 8766   # Steam communication port 1
  SteamPort2           = 8767   # Steam communication port 2

  #---------------------------------------------------------
  # Server Browser Settings
  #---------------------------------------------------------
  PublicName           = "$Name Server"              # Server name in server browser
  PublicDescription    = "A Project Zomboid server"  # Description shown in browser
  Public               = $true                       # Show server in public browser ($true/$false)
  Password             = ""                          # Server password (leave empty for no password)
  MaxPlayers           = 16                          # Maximum player count (1-128)

  #---------------------------------------------------------
  # Mod Configuration
  #---------------------------------------------------------
  # Steam Workshop integration
  # ModList contains mod folder names (with backslash prefix), WorkshopItems contains Steam Workshop IDs
  #
  # For Workshop mods:
  #   1. Find the Steam Workshop item ID (e.g., 2256623447)
  #   2. Add mod folder name to ModList with backslash prefix: "\firearmmod;"
  #   3. Add workshop ID to WorkshopItems: "2256623447;"
  #
  # Example with 2 workshop mods and 1 local mod:
  #   ModList          = "\firearmmod;\someothermod;\LocalModName;"
  #   WorkshopItems    = "2256623447;2920899878;"
  #
  # Note: Both fields are semicolon-separated with trailing semicolon
  # Note: Backslash prefix (\) is required for server INI compatibility
  ModList              = ""  # Mod folder names: "\modname1;\modname2;\modname3;"
  WorkshopItems        = ""  # Workshop IDs only: "id1;id2;id3;"

  #---------------------------------------------------------
  # Game Settings
  #---------------------------------------------------------
  WelcomeMessage       = "Welcome to $Name!"  # Message shown when players join
  SaveWorldEveryMinutes = 0                   # Auto-save frequency (0=default, 1-60=custom)
  ResetID              = 0                    # Increment to force character reset (0=disabled)

  #---------------------------------------------------------
  # Server Installation
  #---------------------------------------------------------

  #Name of the Server Instance
  Name               = $Name

  #Server Installation Path
  Path               = ".\servers\$Name"

  #Server configuration folder
  ConfigFolder       = ".\servers\$Name\Zomboid\Server"

  #Steam Server App Id
  AppID              = 380870

  #Name of the Beta Build
  BetaBuild          = ""

  #Beta Build Password
  BetaBuildPassword  = ""

  #Set to $true if you want this server to automatically update.
  AutoUpdates        = $true

  #Set to $true if you want this server to automatically check for Workshop mod updates.
  #When enabled, a background watcher checks Steam Workshop and triggers a restart when mods are updated.
  AutoModUpdates     = $true

  #Set to $true if you want this server to automatically restart on crash.
  AutoRestartOnCrash = $true

  #Set to $true if you want this server to automatically restart at set hour.
  AutoRestart        = $true

  #The time at which the server will restart daily.
  #(Hour, Minute, Seconds)
  AutoRestartTime    = @(3, 0, 0)

  #Process name in the task manager
  ProcessName        = "java"

  #Use PID instead of Process Name.
  UsePID             = $true

  #Server Executable
  Exec               = ".\servers\$Name\StartServer64.bat"

  #Allow force close, usefull for server without RCON.
  AllowForceClose    = $true

  #Process Priority Realtime, High, AboveNormal, Normal, BelowNormal, Low
  UsePriority        = $true
  AppPriority        = "High"

  <#
  Process Affinity (Core Assignation)
  Core 1 = > 00000001 = > 1
  Core 2 = > 00000010 = > 2
  Core 3 = > 00000100 = > 4
  Core 4 = > 00001000 = > 8
  Core 5 = > 00010000 = > 16
  Core 6 = > 00100000 = > 32
  Core 7 = > 01000000 = > 64
  Core 8 = > 10000000 = > 128
  ----------------------------
  8 Cores = > 11111111 = > 255
  4 Cores = > 00001111 = > 15
  2 Cores = > 00000011 = > 3
  #>

  UseAffinity        = $false
  AppAffinity        = 15

  #Should the server validate install after installation or update *(recommended)
  Validate           = $true

  #How long should it wait to check if the server is stable
  StartupWaitTime    = 10
}
#Create the object
$Server = New-Object -TypeName PsObject -Property $ServerDetails

#---------------------------------------------------------
# Sandbox Settings (Game Rules)
#---------------------------------------------------------
# These settings control gameplay difficulty and mechanics
# Applied via SandboxVars.lua on first setup
# To reset and reapply: delete the _SandboxVars_template.lua file in server config folder

$SandboxSettings = @{
  # Use this to enable/disable sandbox configuration
  Use                  = $false  # Set to $true to apply sandbox settings below

  # Population & Spawning
  Zombies              = 4       # Zombie population multiplier (1=Insane, 2=Very High, 3=High, 4=Normal)
  Distribution         = 1       # Zombie distribution (1=Urban Focused)
  DayLength            = 3       # Day length (1=15min, 2=30min, 3=1hr, 4=2hr, 5=3hr, etc.)
  StartMonth           = 7       # Starting month (1=Jan, 7=July, etc.)
  StartDay             = 9       # Starting day of month

  # Loot & Resources
  LootRespawn          = 1       # Loot respawn (1=None, 2=Every Day, 3=Every Week, etc.)

  # World Settings
  FarmingSpeed         = 3       # Crop growth speed (1=Very Fast, 2=Fast, 3=Normal, 4=Slow)
  NatureAbundance      = 3       # Foraging yield (1=Very Poor, 2=Poor, 3=Normal, 4=Abundant)
  Temperature          = 3       # Temperature effects (1=Very Cold, 2=Cold, 3=Normal, 4=Hot)
  Rain                 = 3       # Rain frequency (1=Very Dry, 2=Dry, 3=Normal, 4=Rainy)

  # Other Settings (add more as needed)
  # See game's default SandboxVars.lua for all available options
}

# Create the Sandbox object
$Sandbox = New-Object -TypeName PsObject -Property $SandboxSettings

#---------------------------------------------------------
# Backups
#---------------------------------------------------------
$BackupsDetails = @{
  #Do Backups
  Use   = $true

  #Backup Folder
  Path  = ".\backups\$($Server.Name)"

  #Number of days of backups to keep.
  Days  = 7

  #Number of weeks of weekly backups to keep.
  Weeks = 4

  #Folder to include in backup
  Saves = "$($Server.Path)\Zomboid"

  #Exclusions (Regex use | as separator) - Exclude PZ backups folder, console logs, debug logs, and vehicle cache files
  Exclusions = "(\\backups\\|\\backups$|.*console\.txt$|.*DebugLog.*\.txt$|.*_vehicle\.bin$)"

  #Compression settings for smallest backup files (change to 'Fast' and 'Zip' for faster backups)
  CompressionLevel   = "Ultra"      # Options: None, Fast, Low, Normal, High, Ultra
  CompressionFormat  = "SevenZip"   # Options: Zip, SevenZip (7z format is 10-30% smaller)
  CompressionMethod  = "Lzma2"      # Options: Lzma, Lzma2, PPMd (for 7z format only)
}
#Create the object
$Backups = New-Object -TypeName PsObject -Property $BackupsDetails

#---------------------------------------------------------
# Restart Warnings (Require RCON, Telnet or WebSocket API)
#---------------------------------------------------------
$WarningsDetails = @{
  #Use Rcon to restart server softly.
  Use        = $true

  #What protocol to use : RCON, ARRCON, Telnet, Websocket
  Protocol   = "RCON"

  #Times at which the servers will warn the players that it is about to restart. (in seconds between each timers)
  Timers     = [System.Collections.ArrayList]@(240, 50, 10) #Total wait time is 240+50+10 = 300 seconds or 5 minutes

  #message that will be sent. % is a wildcard for the timer.
  MessageMin = "`\`"The server will restart in % minutes !`\`""
  
  #message that will be sent. % is a wildcard for the timer.
  MessageSec = "`\`"The server will restart in % seconds !`\`""

  #command to send a message.
  CmdMessage = "servermsg"

  #command to save the server
  CmdSave    = "save"

  #How long to wait in seconds after the save command is sent.
  SaveDelay  = 15

  #command to stop the server
  CmdStop    = "quit"
}
#Create the object
$Warnings = New-Object -TypeName PsObject -Property $WarningsDetails

#---------------------------------------------------------
# Launch Arguments
#---------------------------------------------------------

#Java Arguments
$PZ_CLASSPATH_LIST = @(
  "java/istack-commons-runtime.jar;",
  "java/jassimp.jar;",
  "java/javacord-2.0.17-shaded.jar;",
  "java/javax.activation-api.jar;",
  "java/jaxb-api.jar;",
  "java/jaxb-runtime.jar;",
  "java/lwjgl.jar;",
  "java/lwjgl-natives-windows.jar;",
  "java/lwjgl-glfw.jar;",
  "java/lwjgl-glfw-natives-windows.jar;",
  "java/lwjgl-jemalloc.jar;",
  "java/lwjgl-jemalloc-natives-windows.jar;",
  "java/lwjgl-opengl.jar;",
  "java/lwjgl-opengl-natives-windows.jar;",
  "java/lwjgl_util.jar;",
  "java/commons-compress-1.18.jar;",
  "java/sqlite-jdbc-3.27.2.1.jar;",
  "java/trove-3.0.3.jar;",
  "java/uncommons-maths-1.2.3.jar;",
  "java/"
)

$PZ_CLASSPATH = $PZ_CLASSPATH_LIST -join ""
#Launch Arguments
$ArgumentList = @(
  "-Djava.awt.headless=true ",
  "-Dzomboid.steam=1 ",
  "-Dzomboid.znetlog=1 ",
  "-XX:+UseZGC ",
  "-XX:-CreateCoredumpOnCrash ",
  "-XX:-OmitStackTraceInFastThrow ",
  "-Xms$($Server.JavaHeapMin)g ",
  "-Xmx$($Server.JavaHeapMax)g ",
  "-Djava.library.path=natives/;natives/win64/;. ",
  "-cp $PZ_CLASSPATH zombie.network.GameServer ",
  "-cachedir=.\Zomboid ",
  "-servername `"$($Server.ServerName)`" "
)

Add-Member -InputObject $Server -Name "ArgumentList" -Type NoteProperty -Value $ArgumentList
Add-Member -InputObject $Server -Name "Launcher" -Type NoteProperty -Value "$($Server.Path)\jre64\bin\java.exe"
Add-Member -InputObject $Server -Name "WorkingDirectory" -Type NoteProperty -Value "$($Server.Path)"

#---------------------------------------------------------
# Helper Functions for Template Generation
#---------------------------------------------------------

#---------------------------------------------------------
# Helper: Check if .psm1 config has changed since last template generation
#---------------------------------------------------------
function Test-ConfigModified {
  param(
    [string]$ConfigFile,
    [string]$TemplateFile
  )

  # If template doesn't exist, config is "modified" (needs initial generation)
  if (-not (Test-Path $TemplateFile)) {
    return $true
  }

  # Compare modification times
  $configModTime = (Get-Item $ConfigFile).LastWriteTime
  $templateModTime = (Get-Item $TemplateFile).LastWriteTime

  # If .psm1 is newer than template, regenerate
  return ($configModTime -gt $templateModTime)
}

#---------------------------------------------------------
# Helper: Generate reference template .ini file with recommended settings
#---------------------------------------------------------
function New-ReferenceTemplate {
  param(
    [string]$TemplateFile
  )

  Write-ScriptMsg "Generating reference template: $TemplateFile"

  # Build INI content from .psm1 variables
  $templateContent = @"
# ============================================================
# PROJECT ZOMBOID SERVER CONFIGURATION TEMPLATE
# ============================================================
# This file is a REFERENCE generated from your .psm1 config
# Copy settings you want into the actual game config file
#
# ACTUAL GAME CONFIG: $($Server.ServerName).ini
# THIS IS A REFERENCE: $($Server.ServerName)_template.ini
#
# HOW TO USE:
#   1. Open both files side-by-side
#   2. Copy settings you want from this template
#   3. Paste into the actual .ini file
#   4. Save and restart server
# ============================================================

# RCON Settings
RCONPort=$($Server.ManagementPort)
RCONPassword=$($Server.ManagementPassword)

# Server Browser Settings
PublicName=$($Server.PublicName)
PublicDescription=$($Server.PublicDescription)
Password=$($Server.Password)
MaxPlayers=$($Server.MaxPlayers)
Public=$(if ($Server.Public) { "true" } else { "false" })

# Game Settings
ServerWelcomeMessage=$($Server.WelcomeMessage)
"@

  # Add optional settings if they're configured
  if ($Server.SaveWorldEveryMinutes -gt 0) {
    $templateContent += "`nSaveWorldEveryMinutes=$($Server.SaveWorldEveryMinutes)"
  }

  if ($Server.ResetID -gt 0) {
    $templateContent += "`nResetID=$($Server.ResetID)"
  }

  # Add mod configuration
  if ($Server.ModList) {
    $templateContent += "`n`n# Mod Configuration"
    $templateContent += "`nMods=$($Server.ModList)"
  }

  if ($Server.WorkshopItems) {
    $templateContent += "`nWorkshopItems=$($Server.WorkshopItems)"
  }

  # Write template file
  Set-Content -Path $TemplateFile -Value $templateContent -Force
  Write-ScriptMsg "Template generated successfully!"
}

#---------------------------------------------------------
# Helper: Generate reference template Lua file with sandbox settings
#---------------------------------------------------------
function New-SandboxTemplate {
  param(
    [string]$TemplateFile
  )

  Write-ScriptMsg "Generating Sandbox reference template: $TemplateFile"

  # Build Lua content from .psm1 variables
  $templateContent = @"
-- ============================================================
-- PROJECT ZOMBOID SANDBOX CONFIGURATION TEMPLATE
-- ============================================================
-- This file is a REFERENCE generated from your .psm1 config
-- Copy settings you want into the actual SandboxVars.lua file
--
-- ACTUAL GAME CONFIG: $($Server.ServerName)_SandboxVars.lua
-- THIS IS A REFERENCE: $($Server.ServerName)_SandboxVars_template.lua
--
-- HOW TO USE:
--   1. Open both files side-by-side
--   2. Find the setting you want to change in this template
--   3. Copy the line into the actual SandboxVars.lua file
--   4. Save and restart server
-- ============================================================

SandboxVars = {
    -- Population & Spawning
    Zombies = $($Sandbox.Zombies),
    Distribution = $($Sandbox.Distribution),
    DayLength = $($Sandbox.DayLength),
    StartMonth = $($Sandbox.StartMonth),
    StartDay = $($Sandbox.StartDay),

    -- Loot & Resources
    LootRespawn = $($Sandbox.LootRespawn),

    -- World Settings
    FarmingSpeed = $($Sandbox.FarmingSpeed),
    NatureAbundance = $($Sandbox.NatureAbundance),
    Temperature = $($Sandbox.Temperature),
    Rain = $($Sandbox.Rain),
}
"@

  # Write template file
  Set-Content -Path $TemplateFile -Value $templateContent -Force
  Write-ScriptMsg "Sandbox template generated successfully!"
}

#---------------------------------------------------------
# Function that runs just before the server starts.
#---------------------------------------------------------

function Start-ServerPrep {

  Write-ScriptMsg "Port Forward : $($Server.GamePort), $($Server.SteamPort1) and $($Server.SteamPort2) in TCP and UDP to $($Global.InternalIP)"

  # Define file paths
  $ServerIniFile = "$($Server.ConfigFolder)\$($Server.ServerName).ini"
  $TemplateIniFile = "$($Server.ConfigFolder)\$($Server.ServerName)_template.ini"
  $SandboxFile = "$($Server.ConfigFolder)\$($Server.ServerName)_SandboxVars.lua"
  $SandboxTemplate = "$($Server.ConfigFolder)\$($Server.ServerName)_SandboxVars_template.lua"

  # Get path to this .psm1 config file for modification time tracking
  $ConfigPath = "$PSScriptRoot\..\configs\$($Server.Name).psm1"
  if (-not (Test-Path $ConfigPath)) {
    # Try template path if config doesn't exist yet
    $ConfigPath = "$PSScriptRoot\..\templates\projectzomboid.psm1"
  }

  # ===================================================================
  # PHASE 1: Check if actual game config exists
  # ===================================================================

  if (-not (Test-Path $ServerIniFile)) {
    Write-Host ""
    Write-ScriptMsg "=========================================="
    Write-ScriptMsg "FIRST TIME SETUP - CONFIGURATION NEEDED"
    Write-ScriptMsg "=========================================="
    Write-Host ""
    Write-ScriptMsg "The game config file does not exist yet."
    Write-ScriptMsg "The server will create default configs on first launch."
    Write-Host ""
    Write-ScriptMsg "After the server creates the default files:"
    Write-ScriptMsg "  1. Stop the server"
    Write-ScriptMsg "  2. Check the config folder: $($Server.ConfigFolder)"
    Write-ScriptMsg "  3. Look for _template.ini files - these are REFERENCE EXAMPLES"
    Write-ScriptMsg "  4. Copy settings you want from _template files into actual .ini files"
    Write-ScriptMsg "  5. Restart the server"
    Write-Host ""
    return
  }

  # ===================================================================
  # PHASE 2: Generate/Update Reference Templates (if .psm1 changed)
  # ===================================================================

  # Check if INI template needs regeneration
  if (Test-ConfigModified -ConfigFile $ConfigPath -TemplateFile $TemplateIniFile) {
    Write-Host ""
    Write-ScriptMsg "Configuration file has been updated - regenerating reference template..."
    New-ReferenceTemplate -TemplateFile $TemplateIniFile

    Write-Host ""
    Write-ScriptMsg "=========================================="
    Write-ScriptMsg "REFERENCE TEMPLATE UPDATED"
    Write-ScriptMsg "=========================================="
    Write-Host ""
    Write-ScriptMsg "Your .psm1 configuration has changed."
    Write-ScriptMsg "A new reference template has been generated at:"
    Write-ScriptMsg "  $TemplateIniFile"
    Write-Host ""
    Write-ScriptMsg "TO APPLY THESE SETTINGS:"
    Write-ScriptMsg "  1. Open the _template.ini file (reference)"
    Write-ScriptMsg "  2. Open the actual .ini file: $ServerIniFile"
    Write-ScriptMsg "  3. Copy settings you want from template to actual file"
    Write-ScriptMsg "  4. Save and restart server"
    Write-Host ""
  } else {
    Write-ScriptMsg "Using existing configuration (no .psm1 changes detected)"
  }

  # Check if Sandbox template needs regeneration (if enabled)
  if ($Sandbox.Use) {
    if (Test-Path $SandboxFile) {
      if (Test-ConfigModified -ConfigFile $ConfigPath -TemplateFile $SandboxTemplate) {
        Write-ScriptMsg "Regenerating Sandbox reference template..."
        New-SandboxTemplate -TemplateFile $SandboxTemplate

        Write-Host ""
        Write-ScriptMsg "Sandbox template updated at: $SandboxTemplate"
        Write-ScriptMsg "Review and copy desired settings to: $SandboxFile"
        Write-Host ""
      }
    } else {
      Write-Host ""
      Write-ScriptMsg "SandboxVars.lua will be created on first player join."
      Write-ScriptMsg "After it's created, rerun the launcher to generate reference templates."
      Write-Host ""
    }
  }

  # ===================================================================
  # PHASE 3: Display Current Configuration Summary
  # ===================================================================

  # Read current values from actual game config (if readable)
  if (Test-Path $ServerIniFile) {
    Write-Host ""
    Write-ScriptMsg "Current Server Configuration:"

    $currentName = Get-IniValue -file $ServerIniFile -category "" -key "PublicName"
    $currentMaxPlayers = Get-IniValue -file $ServerIniFile -category "" -key "MaxPlayers"
    $currentMods = Get-IniValue -file $ServerIniFile -category "" -key "Mods"

    if ($currentName) { Write-ScriptMsg "  Server Name: $currentName" }
    if ($currentMaxPlayers) { Write-ScriptMsg "  Max Players: $currentMaxPlayers" }
    if ($currentMods) {
      $modCount = ($currentMods -split ';' | Where-Object { $_ -ne "" }).Count
      Write-ScriptMsg "  Mods: $modCount configured"
    }
    Write-Host ""
  }

}

#---------------------------------------------------------
# TROUBLESHOOTING
#---------------------------------------------------------
#
# Q: Server doesn't appear in browser?
# A: Check PublicName is set, Public=$true, ports are forwarded
#
# Q: Server crashes on start?
# A: Reduce JavaHeapMax to 4-6GB, check system has enough free RAM
#
# Q: Mods not loading?
# A: Verify ModList and WorkshopItems both contain the same workshop IDs
#    Ensure mods are compatible with your server's BetaBuild version
#
# Q: Settings not applying?
# A: Delete the _template.ini and _template.lua files to reset, then rerun
#
# Q: How do I change game difficulty?
# A: Set $SandboxSettings.Use = $true and configure values below
#
# For more help, see CLAUDE.md or visit the Project Zomboid wiki

Export-ModuleMember -Function Start-ServerPrep -Variable @("Server", "Backups", "Warnings", "Sandbox")

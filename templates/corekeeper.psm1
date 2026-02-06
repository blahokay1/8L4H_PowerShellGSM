#Server Name, Always Match the Launcher and config file name.
$Name = $ServerCfg

#---------------------------------------------------------
# Server Configuration
#---------------------------------------------------------

$ServerDetails = @{

  #Login username used by SteamCMD
  Login              = "anonymous"

  #Server Name (displayed in server browser)
  ServerName         = "My Core Keeper Server"

  #Server Password (Direct Connect only, max 28 characters. Leave empty for no password)
  Password           = ""

  #Maximum number of players
  MaxPlayers         = 10

  #Server Port (UDP, used for Direct Connect mode)
  #To use SDR (Steam Datagram Relay) instead, set Port to 0
  Port               = 27016

  #World index (0, 1, 2, etc. - each index is a separate world save)
  WorldIndex         = 0

  #World Seed (leave empty for random seed)
  WorldSeed          = ""

  #World Mode: 0 = Normal, 1 = Hard, 2 = Creative, 4 = Casual
  WorldMode          = 0

  #Season Override (leave empty for default)
  #0 = None, 1 = Easter, 2 = Halloween, 3 = Christmas, 4 = Valentine,
  #5 = Anniversary, 6 = CherryBlossom, 7 = LunarNewYear
  Season             = ""

  #Game ID (15-28 alphanumeric characters. Leave empty for auto-generated)
  GameID             = ""

  #Platform Filter (leave empty for all platforms)
  #1 = Steam, 2 = Epic, 3 = Microsoft, 4 = GOG
  AllowOnlyPlatform  = ""

  #Rcon IP (Core Keeper does not support RCON)
  ManagementIP       = "127.0.0.1"

  #Rcon Port (not supported)
  ManagementPort     = ""

  #Rcon Password (not supported)
  ManagementPassword = ""

  #---------------------------------------------------------
  # Server Installation Details
  #---------------------------------------------------------

  #Name of the Server Instance
  Name               = $Name

  #Server Installation Path
  Path               = ".\servers\$Name"

  #Server configuration folder
  ConfigFolder       = ".\servers\$Name"

  #Steam Server App Id
  AppID              = 1963720

  #Name of the Beta Build
  BetaBuild          = ""

  #Beta Build Password
  BetaBuildPassword  = ""

  #Set to $true if you want this server to automatically update.
  AutoUpdates        = $true

  #Set to $true if you want this server to automatically restart on crash.
  AutoRestartOnCrash = $true

  #Set to $true if you want this server to automatically restart at set hour.
  AutoRestart        = $true

  #The time at which the server will restart daily.
  #(Hour, Minute, Seconds)
  AutoRestartTime    = @(3, 0, 0)

  #Process name in the task manager
  ProcessName        = "CoreKeeperServer"

  #Use PID instead of Process Name.
  UsePID             = $true

  #Server Executable
  Exec               = ".\servers\$Name\CoreKeeperServer.exe"

  #Allow force close, required for servers without RCON.
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
  Saves = ".\servers\$($Server.Name)\data"

  #Exclusions (Regex use | as separator)
  Exclusions = ""
}
#Create the object
$Backups = New-Object -TypeName PsObject -Property $BackupsDetails

#---------------------------------------------------------
# Restart Warnings (Require RCON, Telnet or WebSocket API)
#---------------------------------------------------------

$WarningsDetails = @{
  #Use Rcon to restart server softly. (Core Keeper does not support RCON)
  Use        = $false

  #What protocol to use : RCON, ARRCON, Telnet, Websocket
  Protocol   = "RCON"

  #Times at which the servers will warn the players that it is about to restart. (in seconds between each timers)
  Timers     = [System.Collections.ArrayList]@(240, 50, 10) #Total wait time is 240+50+10 = 300 seconds or 5 minutes

  #message that will be sent. % is a wildcard for the timer.
  MessageMin = "The server will restart in % minutes !"

  #message that will be sent. % is a wildcard for the timer.
  MessageSec = "The server will restart in % seconds !"

  #command to send a message.
  CmdMessage = "say"

  #command to save the server
  CmdSave    = "save"

  #How long to wait in seconds after the save command is sent.
  SaveDelay  = 15

  #command to stop the server
  CmdStop    = "shutdown"
}
#Create the object
$Warnings = New-Object -TypeName PsObject -Property $WarningsDetails

#---------------------------------------------------------
# Launch Arguments
#---------------------------------------------------------

#Launch Arguments
$ArgumentList = @(
  "-batchmode ",
  "-logfile `"logs\CoreKeeper.log`" ",
  "-world $($Server.WorldIndex) ",
  "-worldname `"$($Server.ServerName)`" ",
  "-worldmode $($Server.WorldMode) ",
  "-datapath `"data`" ",
  "-maxplayers $($Server.MaxPlayers) "
)

#Add Direct Connect arguments if Port is set
if ($Server.Port -and $Server.Port -ne 0) {
  $ArgumentList += "-ip $($Global.InternalIP) "
  $ArgumentList += "-port $($Server.Port) "
}

#Add optional arguments only if values are set
if ($Server.WorldSeed -ne "") {
  $ArgumentList += "-worldseed `"$($Server.WorldSeed)`" "
}

if ($Server.Season -ne "") {
  $ArgumentList += "-season $($Server.Season) "
}

if ($Server.GameID -ne "") {
  $ArgumentList += "-gameid `"$($Server.GameID)`" "
}

if ($Server.Password -ne "") {
  $ArgumentList += "-password `"$($Server.Password)`" "
}

if ($Server.AllowOnlyPlatform -ne "") {
  $ArgumentList += "-allowonlyplatform $($Server.AllowOnlyPlatform) "
}

Add-Member -InputObject $Server -Name "ArgumentList" -Type NoteProperty -Value $ArgumentList
Add-Member -InputObject $Server -Name "Launcher" -Type NoteProperty -Value "$($Server.Exec)"
Add-Member -InputObject $Server -Name "WorkingDirectory" -Type NoteProperty -Value "$($Server.Path)"

#---------------------------------------------------------
# Function that runs just before the server starts.
#---------------------------------------------------------

function Start-ServerPrep {

  #Create data directory for world saves if it does not exist
  if (-not (Test-Path "$($Server.Path)\data")) {
    $null = New-Item -ItemType "directory" -Path "$($Server.Path)\data" -Force
  }

  #Create logs directory if it does not exist
  if (-not (Test-Path "$($Server.Path)\logs")) {
    $null = New-Item -ItemType "directory" -Path "$($Server.Path)\logs" -Force
  }

  if ($Server.Port -and $Server.Port -ne 0) {
    Write-ScriptMsg "Port Forward : $($Server.Port) in UDP to $($Global.InternalIP)"
  } else {
    Write-ScriptMsg "Using SDR (Steam Datagram Relay) mode. No port forwarding required."
  }

  Write-ScriptMsg "Players can join using the Game ID found in $($Server.Path)\GameID.txt after first start."

}

Export-ModuleMember -Function Start-ServerPrep -Variable @("Server", "Backups", "Warnings")

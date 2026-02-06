# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PowerShellGSM is a PowerShell tool for automated game server management on Windows. It handles installation, updates, monitoring, backups, and automated restarts for various game servers using SteamCMD.

**Supported Games**: 7 Days to Die, Ark: Survival Ascended, Astroneer, Conan Exiles, Enshrouded, Icarus, Insurgency Sandstorm, Killing Floor 2, Left 4 Dead 2, Minecraft (Paperclip), Mordhau, Palworld, PixArk, Project Zomboid, Rust, Satisfactory, Squad, Starbound, Stationeers, Terraria, The Forest, Valheim, V Rising

**Requirements**: Windows 10+ with PowerShell 5.1+, admin user (but NOT elevated execution)

## Development Commands

```powershell
# Test a server configuration
.\launchers\<servername>.cmd

# Direct server operation
.\main.ps1 -ServerCfg "icarus"

# Lint a file
Invoke-ScriptAnalyzer -Path .\path\to\file.ps1 -Settings .\.vscode\PSScriptAnalyzerSettings.psd1

# Install optional 7z compression (better backup compression)
Install-Module -Name 7Zip4Powershell
```

**Linting Config** (`.vscode/PSScriptAnalyzerSettings.psd1`): Error/Warning severity only; excludes UseDeclaredVarsMoreThanAssignments, UseShouldProcessForStateChangingFunctions, ProvideCommentHelp, and password/write-host rules.

## Core Architecture

### Entry Point and Flow

`main.ps1` orchestrates the server lifecycle:
1. Imports `global.psm1` and all functions from `functions/` subdirectories
2. Imports server config from `configs/$ServerCfg.psm1`
3. Calls `Read-Config` to resolve paths and build arguments
4. Flow: Check/Install → Stop → Backup → Update → Start → Spawn server watcher

### Configuration System

- **Templates**: `templates/*.psm1` - Pre-configured templates for supported games
- **Active Configs**: `configs/*.psm1` - User copies from templates
- **Launchers**: `launchers/<name>.cmd` matches `configs/<name>.psm1` via filename
- **Exports**: Each config exports `$Server`, `$Backups`, `$Warnings` objects

### Function Organization (`functions/`)

| Directory | Purpose |
|-----------|---------|
| `ini/` | INI file manipulation (Get/Set-IniValue) |
| `install/` | Dependency installation (SteamCMD, ARRCON, mcrcon, Java) |
| `network/` | Download, Telnet, RCON commands, IP detection |
| `process/` | PID tracking, priority/affinity, file-based locking |
| `server/` | Start/Stop/Update/Backup/RestartWarning |
| `util/` | Logging, config, cleanup, Set-LuaValue |

### Server Watcher System

`server-watcher.ps1` is an interactive background process that monitors the server:

- **Alive Check**: Restarts if crashed (`AutoRestartOnCrash`)
- **Update Check**: Every `UpdateCheckFrequency` minutes via SteamCMD (`AutoUpdates`)
- **Auto Restart**: Daily at `AutoRestartTime` (`AutoRestart`)
- **Mod Update Check**: Every `ModCheckFrequency` minutes via Steam Workshop API (`AutoModUpdates`)

When restart is needed, the watcher invokes `main.ps1` and exits. The new `main.ps1` spawns a fresh watcher.

**Key Files**:
- `.\servers\<Name>_ServerWatcher.PID` - Watcher process ID
- `.\logs\server-watcher-<Name>.txt` - Watcher log (append mode)

### Process Locking

File-based locking (`Get-Lock`, `Lock-Process`, `Unlock-Process`) prevents concurrent execution:
- Lock files: `.\locks\$ServerCfg.lock`
- Timeout: 120 minutes (stale locks auto-removed)

### Backup System

`Backup-Server.psm1` creates intelligent backups:
- **Daily vs Weekly**: Friday = "Weekly" (kept for weeks), others = "Daily" (kept for days)
- **Exclusions**: Global extensions (`.tmp`, `.bak`, `.log`, `.dmp`, `.cache`) + per-server regex
- **Compression**: 7Zip4PowerShell (preferred) or Compress-Archive fallback

Optional `$BackupsDetails` settings:
```powershell
CompressionLevel  = "Ultra"     # None, Fast, Low, Normal, High, Ultra
CompressionFormat = "SevenZip"  # Zip, SevenZip
CompressionMethod = "Lzma2"     # Lzma, Lzma2, PPMd (7z only)
```

### Runtime Properties

`$Global.InternalIP` and `$Global.ExternalIP` are added dynamically by `Set-IP` (not in `global.psm1`). Available in `Start-ServerPrep` and argument lists.

### Remote Management

`Send-Command` supports: RCON (mcrcon.exe), ARRCON, Telnet, Websocket

## Important Patterns

### Path Resolution

**CRITICAL**: All paths resolved via `Resolve-CompletePath`. Must use one of:

1. `".\servers\$Name\subfolder"` - Server-relative (preferred)
2. `"$Env:userprofile\Zomboid"` - Environment variables
3. `"$($Server.Path)\subfolder"` - Using Server.Path

**Common Mistake**: `"$Name\subfolder"` without `".\servers\"` prefix creates folders in wrong locations.

### Argument Construction

Arguments are arrays with trailing spaces, joined by `Optimize-ArgumentList`:
```powershell
$ArgumentList = @(
  "-PORT=$($Server.Port) ",
  "-QueryPort=$($Server.QueryPort) "
)
```

### Configuration File Helpers

**INI files**: `Set-IniValue -file $File -category "" -key "Port" -value 27015`

**Lua tables**: `Set-LuaValue -File $File -Table "SandboxVars" -Key "Zombies" -Value 5`

### Error Handling

`Exit-WithError` for critical failures - displays error, optionally pauses, unlocks process, exits.

### Logging

- `Start-Transcript` to `.\logs\<timestamp>-<servername>.txt`
- Use `Write-ScriptMsg` for script ops, `Write-ServerMsg` for server-specific
- Auto-deleted after 30 days (`$Global.Days`)

## Two-Phase First Launch

**Phase 1 - Installation**:
1. User runs launcher
2. SteamCMD installs server
3. Script stops and opens config folder in Explorer

**Phase 2 - First Start**:
1. User runs launcher again
2. Server starts with configurations
3. Watcher spawns for monitoring

## Template Skeleton

New templates go in `templates/<game>.psm1`:

```powershell
$Name = $ServerCfg

$ServerDetails = @{
  Login              = "anonymous"
  ServerName         = "My Server"
  Port               = 27015
  ManagementIP       = "127.0.0.1"
  ManagementPort     = ""
  ManagementPassword = ""
  Name               = $Name
  Path               = ".\servers\$Name"
  ConfigFolder       = ".\servers\$Name"
  AppID              = 0
  BetaBuild          = ""
  BetaBuildPassword  = ""
  AutoUpdates        = $true
  AutoModUpdates     = $false
  AutoRestartOnCrash = $true
  AutoRestart        = $true
  AutoRestartTime    = @(3, 0, 0)  # Hour, Minute, Seconds
  ProcessName        = "ServerExecutable"
  UsePID             = $true
  Exec               = ".\servers\$Name\ServerExecutable.exe"
  AllowForceClose    = $true
  UsePriority        = $true
  AppPriority        = "High"
  UseAffinity        = $false
  AppAffinity        = 15
  Validate           = $true
  StartupWaitTime    = 10
}
$Server = New-Object -TypeName PsObject -Property $ServerDetails

$BackupsDetails = @{
  Use        = $true
  Path       = ".\backups\$($Server.Name)"
  Days       = 7
  Weeks      = 4
  Saves      = ".\servers\$($Server.Name)\savedata"
  Exclusions = ""  # Regex with | separator
}
$Backups = New-Object -TypeName PsObject -Property $BackupsDetails

$WarningsDetails = @{
  Use        = $false  # $true if RCON/Telnet/Websocket supported
  Protocol   = "RCON"  # RCON, ARRCON, Telnet, Websocket
  Timers     = [System.Collections.ArrayList]@(240, 50, 10)
  MessageMin = "The server will restart in % minutes !"
  MessageSec = "The server will restart in % seconds !"
  CmdMessage = "say"
  CmdSave    = "save"
  SaveDelay  = 15
  CmdStop    = "shutdown"
}
$Warnings = New-Object -TypeName PsObject -Property $WarningsDetails

$ArgumentList = @(
  "-batchmode ",
  "-port $($Server.Port) "
)

Add-Member -InputObject $Server -Name "ArgumentList" -Type NoteProperty -Value $ArgumentList
Add-Member -InputObject $Server -Name "Launcher" -Type NoteProperty -Value "$($Server.Exec)"
Add-Member -InputObject $Server -Name "WorkingDirectory" -Type NoteProperty -Value "$($Server.Path)"

function Start-ServerPrep {
  Write-ScriptMsg "Port Forward : $($Server.Port) in TCP and UDP to $($Global.InternalIP)"
}

Export-ModuleMember -Function Start-ServerPrep -Variable @("Server", "Backups", "Warnings")
```

Launcher (`launchers/<game>.cmd`):
```batch
cd ..
start powershell.exe -noprofile -executionpolicy bypass -file ".\main.ps1" -ServerCfg "%~n0"
```

## Workshop Mod Update Checking

For Steam Workshop games (e.g., Project Zomboid):

```powershell
# In server config
AutoModUpdates = $true
WorkshopItems  = "2256623447;2920899878;"  # Semicolon-separated Steam IDs
```

Timestamps stored in `.\servers\<Name>_ModTimestamps.INI`. First check records timestamps without triggering restart.

## Game-Specific Notes

### Project Zomboid

**Mod Configuration Format**:
- `ModList`: Folder names with backslash prefix - `"\firearmmod;\othermod;"`
- `WorkshopItems`: Steam IDs only - `"2256623447;2920899878;"`
- Workshop mods need BOTH entries; local mods only need ModList

**Arguments**:
- `-cachedir=.\Zomboid` for self-contained setup
- `-servername "servertest"` must match INI file prefix

**Reference Template Pattern**: Template files (`*_template.ini`, `*_SandboxVars_template.lua`) are reference examples only, regenerated when .psm1 is modified. Users manually copy desired settings to game configs.

## Troubleshooting

**Errant Folder Creation**: Check `$Server.ConfigFolder` and `$Backups.Saves` use proper path patterns (must start with `".\servers\"` or use `$Server.Path`).

**Process Lock Issues**: Check `.\locks\` for stale `.lock` files (auto-removed after 120 minutes).

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PowerShellGSM is a comprehensive PowerShell tool for automated game server management on Windows. It handles installation, updates, monitoring, backups, and automated restarts for various game servers (7 Days to Die, Ark: Survival Ascended, Palworld, Valheim, etc.) using SteamCMD.

## Core Architecture

### Entry Point and Flow

- `main.ps1` - Main entry point that orchestrates the entire server lifecycle
  - Imports `global.psm1` (global configuration) and all functions from `functions/` subdirectories
  - Takes `-ServerCfg` (server name) parameter
  - Execution flow: Import modules → Start logging → Import server config → Check/Install → Stop → Backup → Update → Start → Spawn server watcher

### Configuration System

Server configurations are PowerShell modules (`.psm1`) that define server-specific settings:
- **Templates**: `templates/*.psm1` - Pre-configured templates for supported games
- **Active Configs**: `configs/*.psm1` - User copies from templates (copied on first run)
- **Config Structure**: Each config exports `$Server`, `$Backups`, and `$Warnings` objects with server details, backup settings, and restart warning configurations
- **Launcher Naming**: `launchers/icarus.cmd` matches `configs/icarus.psm1` via filename

The `Read-Config` function (in `functions/util/`) resolves all relative paths to absolute paths and constructs the launch arguments from the `ArgumentList` array.

### Function Organization

Functions are organized by category in `functions/` subdirectories:
- **ini/** - INI file manipulation (Get/Set-IniValue)
- **install/** - Dependency installation (SteamCMD, ARRCON, mcrcon, Java)
- **network/** - Network operations (Download, Telnet, RCON commands, IP detection)
- **process/** - Process management (PID tracking, priority/affinity, locking)
- **server/** - Core server operations (Start/Stop/Update/Backup/RestartWarning)
- **util/** - Utilities (logging, config, task scheduling, cleanup, Set-LuaValue for Lua config files)

### Process Locking

The system uses file-based locking (`Get-Lock`, `Lock-Process`, `Unlock-Process`) to prevent concurrent execution:
- Lock files stored in `.\locks\$ServerCfg.lock`
- Contains timestamp to detect stale locks (timeout: 120 minutes default)
- Prevents conflicts between manual runs and watcher-triggered restarts

### Server Watcher System

The server watcher (`server-watcher.ps1`) is a background process that monitors the server and triggers restarts when needed:

1. **Launch**: After `main.ps1` starts the server, it spawns the watcher as a hidden background process
2. **Monitoring Loop**: The watcher checks every minute for various conditions:
   - **Alive Check**: Verifies server process exists, triggers restart if crashed (`AutoRestartOnCrash`)
   - **Update Check**: Every `UpdateCheckFrequency` minutes, queries SteamCMD for updates (`AutoUpdates`)
   - **Auto Restart**: Triggers restart at configured daily time (`AutoRestart` + `AutoRestartTime`)
   - **Mod Update Check**: Every `ModCheckFrequency` minutes, queries Steam Workshop API (`AutoModUpdates`)
3. **Restart Trigger**: When any check detects a restart is needed, the watcher invokes `main.ps1` and exits
4. **Fresh Watcher**: The new `main.ps1` instance spawns a fresh watcher after starting the server

**Key Files**:
- `.\servers\<ServerName>_ServerWatcher.PID` - PID file for watcher process management
- `.\logs\server-watcher-<ServerName>.txt` - Watcher log file (append mode)

**Watcher Spawn Condition**: The watcher is spawned if any automation feature is enabled:
```powershell
if ($Server.AutoRestartOnCrash -or $Server.AutoUpdates -or $Server.AutoRestart -or ($hasAutoModUpdates -and $hasWorkshopItems)) {
  # Spawn server-watcher.ps1
}
```

### Backup System

Intelligent backup system (`Backup-Server.psm1`):
- **Daily vs Weekly**: Friday backups are "Weekly" (kept for configured weeks), others are "Daily" (kept for configured days)
- **Exclusion Filtering**: Excludes files by extension (global: `.tmp`, `.bak`, `.log`, `.dmp`, `.cache`, etc.) and regex patterns (per-server)
- **Compression**: Configurable compression with 7Zip4PowerShell (preferred) or built-in Compress-Archive (fallback)
  - Supports ZIP and 7z formats (7z is 10-30% smaller)
  - Compression levels: None, Fast, Low, Normal, High, Ultra
  - 7z format supports LZMA2 compression method for optimal game save compression
- **Temp Directory Strategy**: Creates temp dir, copies filtered files preserving structure, compresses, then deletes temp dir
- **Scheduling**: Backups run on every server start (not during watcher-triggered restarts for crashes)

**Configurable Backup Compression** (optional settings in `$BackupsDetails`):
```powershell
CompressionLevel   = "Ultra"      # Options: None, Fast, Low, Normal, High, Ultra
CompressionFormat  = "SevenZip"   # Options: Zip, SevenZip (7z format is smaller)
CompressionMethod  = "Lzma2"      # Options: Lzma, Lzma2, PPMd (7z only)
```

Default behavior (if not specified): Fast compression with ZIP format for backward compatibility.

### Server Lifecycle

**Installation** (first run):
- `Update-Server` uses SteamCMD to install via AppID
- Creates dynamic SteamCMD script (`SteamCMD_$ServerName.txt`) with force_install_dir, login, app_update, validate
- Retries up to 10 times on failure (configurable via `$Global.MaxDownloadRetries`)
- Opens config folder in Explorer and pauses for user to configure

**Starting**:
- Calls `Start-ServerPrep` (defined in each config .psm1) to set up config files
- Launches executable with arguments via `Start-Process`
- Waits `StartupWaitTime` seconds to verify stability
- Sets process priority/affinity if configured
- Registers PID for tracking

**Stopping**:
- Tries graceful shutdown via RCON/Telnet warnings if `$Warnings.Use` is true
- Falls back to forced termination if `AllowForceClose` is true
- `Send-RestartWarning` sends countdown messages before shutdown

**Updating**:
- Uses SteamCMD with `app_update`, optional beta branch, and `validate` flag
- Only runs when not a fresh install and AutoUpdates enabled

### Runtime Properties

`$Global.InternalIP` and `$Global.ExternalIP` are added dynamically at runtime by `Set-IP` (in `functions/network/`). They are NOT defined in `global.psm1` but are available in templates' `Start-ServerPrep` functions and argument lists. `InternalIP` is detected from the active network interface; `ExternalIP` is fetched from `ifconfig.me`.

### Remote Management

`Send-Command` function supports multiple protocols for server control:
- **RCON**: Uses mcrcon.exe (most common)
- **ARRCON**: Alternative RCON implementation
- **Telnet**: For servers with telnet admin interface
- **Websocket**: For servers with WebSocket APIs

Each protocol sends commands (broadcast messages, save, shutdown) configured in `$Warnings` object.

## Development Commands

### Testing a Server Configuration

```powershell
# From PowerShellGSM directory
.\launchers\<servername>.cmd
```

### Manual Server Operations

```powershell
# Install/Update/Start a server (also spawns background watcher)
.\main.ps1 -ServerCfg "icarus"
```

### Creating a New Game Server Configuration

1. Copy a similar template from `templates/` to `configs/`
2. Modify server settings (ports, AppID, executable path, arguments)
3. Create matching `.cmd` launcher in `launchers/`
4. Test with `.\launchers\<newserver>.cmd`

### Linting

PowerShell Script Analyzer is configured in `.vscode/PSScriptAnalyzerSettings.psd1`:
- Severity: Error and Warning only
- Excludes: UseDeclaredVarsMoreThanAssignments, UseShouldProcessForStateChangingFunctions, ProvideCommentHelp, and password/write-host rules

To lint manually:
```powershell
# Install PSScriptAnalyzer if not already installed
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser

# Run analyzer on a file
Invoke-ScriptAnalyzer -Path .\path\to\file.ps1 -Settings .\.vscode\PSScriptAnalyzerSettings.psd1
```

## Important Patterns

### Argument Construction

Server launch arguments are built as arrays in config files, then joined by `Optimize-ArgumentList`:
```powershell
$ArgumentList = @(
  "-PORT=$($Server.Port) ",
  "-QueryPort=$($Server.QueryPort) "
)
```

**Game-Specific Parameters**: Some games require special parameters in the `ArgumentList`:
- **Project Zomboid**:
  - Use `-cachedir=.\Zomboid` to specify where game stores data (works with self-contained setup)
  - Use `-servername "servertest"` to specify the server name (matches INI file prefix)
  - Java heap memory: `-Xms6g -Xmx6g` (should be configurable via variables, not hardcoded)
- **Java-based servers**: Set classpath with `-cp` and specify main class (e.g., `zombie.network.GameServer`)
- Arguments are space-separated; each array element should end with a trailing space

**Start-ServerPrep Function**: Each server config can define a `Start-ServerPrep` function that runs immediately before the server starts. Use this for:
- Creating/modifying config files programmatically (using Set-IniValue or Set-LuaValue)
- Setting up initial world files
- Displaying port forwarding reminders
- Applying managed settings from the .psm1 config to game config files
- Any pre-launch setup tasks

### Configuration File Management

The system supports two types of configuration files:

**INI Files** (e.g., servertest.ini):
- Use `Set-IniValue` from `functions/ini/` to modify settings
- Syntax: `Set-IniValue -file $IniFile -category "" -key "RCONPort" -value $Server.ManagementPort`
- Category can be empty string for flat INI files

**Lua Tables** (e.g., SandboxVars.lua for Project Zomboid):
- Use `Set-LuaValue` from `functions/util/` to modify Lua table values
- Syntax: `Set-LuaValue -File $LuaFile -Table "SandboxVars" -Key "Zombies" -Value 5`
- Automatically handles type detection (strings, numbers, booleans)
- Preserves Lua formatting and indentation

**Reference Template Pattern** (Project Zomboid):
- Template files (`*_template.ini`, `*_SandboxVars_template.lua`) are **reference examples** only
- Generated from .psm1 configuration variables to show recommended settings
- **Never written to actual game config files** - user manually copies desired settings
- Automatically regenerated when .psm1 config file is modified (based on file modification time)
- Users review templates and selectively apply settings to their game configs
- This gives users full control over game configuration while providing helpful examples

**Project Zomboid Mod Configuration**:
Project Zomboid has specific format requirements for mod configuration:
- **ModList**: Contains mod folder names with backslash prefix - `"\firearmmod;\someothermod;\LocalModName;"`
- **WorkshopItems**: Contains Steam Workshop IDs only - `"2256623447;2920899878;"`
- Both fields are semicolon-separated with trailing semicolons
- The backslash `\` prefix is required in ModList for server INI compatibility
- Workshop mods require BOTH the mod name in ModList AND the ID in WorkshopItems
- Local (non-workshop) mods only need the name in ModList (still with backslash prefix)

### Path Resolution

All paths in server configs are resolved to absolute paths via `Resolve-CompletePath` during config read. **CRITICAL**: Paths MUST follow one of these patterns:

1. **Server-relative paths** (preferred): `".\servers\$Name\subfolder"`
   - Must start with `".\servers\"` prefix to trigger proper resolution
2. **Environment variables** (for user profile paths): `"$Env:userprofile\Zomboid"`
3. **Using Server.Path variable**: `"$($Server.Path)\subfolder"`

**Common Mistake**: Using `"$Name\subfolder"` without the `".\servers\"` prefix will cause paths to be resolved relative to the wrong root, potentially creating errant folders in unexpected locations (e.g., drive root).

**Self-Contained vs User Profile Setup**:
- **Self-contained** (recommended): All server data in `.\servers\$Name\` using patterns #1 or #3
- **User profile**: Game data in Windows user profile using pattern #2

Affected config properties:
- `$Server.ConfigFolder` - Where server looks for config files
- `$Backups.Saves` - What directory to backup
- `$Server.Path` - Server installation directory (always `".\servers\$Name"`)

Example (self-contained setup):
```powershell
Path = ".\servers\$Name"
ConfigFolder = ".\servers\$Name\Zomboid\Server"  # Correct
# OR
ConfigFolder = "$($Server.Path)\Zomboid\Server"  # Also correct
Saves = "$($Server.Path)\Zomboid"
```

### Error Handling

Use `Exit-WithError` for critical failures - it displays error, optionally pauses if `$Global.PauseOnErrors` is true, unlocks process, and exits.

### Logging

- All output logged via `Start-Transcript` to `.\logs\<timestamp>-<servername>.txt`
- Use `Write-ScriptMsg` for script operations, `Write-ServerMsg` for server-specific messages
- Old logs auto-deleted after 30 days (configurable via `$Global.Days`)

## Module Exports

Each `.psm1` file exports specific functions/variables:
- Function modules: `Export-ModuleMember -Function <FunctionName>`
- Config modules: `Export-ModuleMember -Variable @("Server", "Backups", "Warnings")`
  - Project Zomboid also exports `"Sandbox"`: `Export-ModuleMember -Variable @("Server", "Backups", "Warnings", "Sandbox")`
- Global module: `Export-ModuleMember -Variable "Global"`

## Two-Phase First Launch

When setting up a new server, the first launch follows a two-phase process:

**Phase 1 - Installation**:
1. User runs launcher (e.g., `.\launchers\icarus.cmd`)
2. Script installs the game server via SteamCMD
3. Script **stops immediately** and opens the server's config folder in Explorer
4. User edits game-specific config files (ports, passwords, world settings, etc.)

**Phase 2 - First Start**:
1. User runs the same launcher again
2. Script starts the server with user's configurations
3. Script spawns background server watcher for monitoring

This pause after installation is intentional - game servers require configuration before first start.

## Template Skeleton

Concise reference for creating new game server templates (`templates/<game>.psm1`):

```powershell
$Name = $ServerCfg

$ServerDetails = @{
  # SteamCMD login
  Login              = "anonymous"
  # Game-specific settings (name, ports, passwords, etc.)
  ServerName         = "My Server"
  Port               = 27015
  ManagementIP       = "127.0.0.1"   # RCON IP (or placeholder if unsupported)
  ManagementPort     = ""
  ManagementPassword = ""
  # Installation details
  Name               = $Name
  Path               = ".\servers\$Name"
  ConfigFolder       = ".\servers\$Name"
  AppID              = 0              # Steam dedicated server App ID
  BetaBuild          = ""
  BetaBuildPassword  = ""
  # Automation
  AutoUpdates        = $true
  AutoModUpdates     = $false         # Steam Workshop mod update checking (requires WorkshopItems)
  AutoRestartOnCrash = $true
  AutoRestart        = $true
  AutoRestartTime    = @(3, 0, 0)     # Hour, Minute, Seconds
  # Process
  ProcessName        = "ServerExecutable"
  UsePID             = $true
  Exec               = ".\servers\$Name\ServerExecutable.exe"
  AllowForceClose    = $true          # Required if no RCON
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
  Exclusions = ""                     # Regex with | separator
}
$Backups = New-Object -TypeName PsObject -Property $BackupsDetails

$WarningsDetails = @{
  Use        = $false                 # $true if RCON/Telnet/Websocket supported
  Protocol   = "RCON"                 # RCON, ARRCON, Telnet, Websocket
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
  "-batchmode ",                      # Trailing space on each element
  "-port $($Server.Port) "
)
# Conditional arguments (pattern from ark_survival_ascended.psm1):
# if ($Server.OptionalField -ne "") { $ArgumentList += "-flag $($Server.OptionalField) " }

Add-Member -InputObject $Server -Name "ArgumentList" -Type NoteProperty -Value $ArgumentList
Add-Member -InputObject $Server -Name "Launcher" -Type NoteProperty -Value "$($Server.Exec)"
Add-Member -InputObject $Server -Name "WorkingDirectory" -Type NoteProperty -Value "$($Server.Path)"

function Start-ServerPrep {
  Write-ScriptMsg "Port Forward : $($Server.Port) in TCP and UDP to $($Global.InternalIP)"
}

Export-ModuleMember -Function Start-ServerPrep -Variable @("Server", "Backups", "Warnings")
```

Each template also needs a matching launcher in `launchers/<game>.cmd`:
```batch
cd ..
start powershell.exe -noprofile -executionpolicy bypass -file ".\main.ps1" -ServerCfg "%~n0"
```

## Troubleshooting

**Errant Folder Creation**: If folders are created in unexpected locations (e.g., drive root), check path configuration:
- Verify `$Server.ConfigFolder` and `$Backups.Saves` use proper path patterns (see Path Resolution section)
- Common issue: missing `".\servers\"` prefix in relative paths

**Process Lock Issues**: If script reports "already running" when it's not:
- Check `.\locks\` folder for stale lock files
- Default timeout is 120 minutes; old locks are auto-removed after timeout
- Manual fix: delete the `.lock` file for the affected server

## Workshop Mod Update Checking

For games with Steam Workshop support (currently Project Zomboid), the server watcher can automatically detect mod updates and trigger a server restart.

### Configuration

**Global setting** (in `global.psm1`):
```powershell
ModCheckFrequency = 30  # Minutes between Steam Workshop API checks
```

**Per-server settings** (in server config `.psm1`):
```powershell
AutoModUpdates = $true   # Enable mod update watching
WorkshopItems  = "2256623447;2920899878;"  # Steam Workshop IDs (semicolon-separated)
```

### Files Created

- `.\servers\<ServerName>_ModTimestamps.INI` - Stores last-known update timestamps per mod

### Key Functions

- `Request-ModUpdate` (in `functions/server/`) - Queries Steam API and compares timestamps
- `server-watcher.ps1` - Comprehensive background monitoring script (handles all automation)

### First-Check Behavior

When checking a mod for the first time (no stored timestamp), the watcher records the current timestamp but does NOT trigger a restart. This prevents a false-positive restart when enabling the feature on an existing server with mods already installed.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PowerShellGSM is a comprehensive PowerShell tool for automated game server management on Windows. It handles installation, updates, monitoring, backups, and automated restarts for various game servers (7 Days to Die, Ark: Survival Ascended, Palworld, Valheim, etc.) using SteamCMD.

## Core Architecture

### Entry Point and Flow

- `main.ps1` - Main entry point that orchestrates the entire server lifecycle
  - Imports `global.psm1` (global configuration) and all functions from `functions/` subdirectories
  - Takes `-ServerCfg` (server name) and optional `-Task` (scheduled task mode) parameters
  - Execution flow: Import modules → Start logging → Import server config → Check/Install → Stop → Backup → Update → Start → Register scheduled tasks

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
- Prevents conflicts between manual runs and scheduled task checks

### Scheduled Task System

Two-tier task system:
1. **Initial Run**: User executes `launchers/*.cmd` which calls `main.ps1`
2. **Scheduled Tasks**: Created via `Register-Task` to run `main.ps1 -Task` every N minutes (default: 5)

The `-Task` parameter triggers periodic checks:
- **Alive Check**: Verifies server process exists, restarts if crashed (AutoRestartOnCrash)
- **Update Check**: Queries SteamCMD for updates (AutoUpdates)
- **Auto Restart**: Scheduled daily restart at configured time (AutoRestart)
- **Backup Check**: Creates backups on configured frequency

Each check has a frequency setting in `global.psm1` and a "next run" timestamp tracked in `.\servers\$ServerCfg.INI`.

**CRITICAL TIMING BUG FIX**: The variable `$TasksSchedule` (loaded via `Get-TaskConfig`) must be initialized BEFORE the `if ($Task)` block in `main.ps1`. This ensures backup frequency checking works correctly for both manual launches and scheduled task mode. If `$TasksSchedule` is only loaded inside the task mode block, manual launches will create backups every time instead of respecting the configured frequency.

### Backup System

Intelligent backup system (`Backup-Server.psm1`):
- **Daily vs Weekly**: Friday backups are "Weekly" (kept for configured weeks), others are "Daily" (kept for configured days)
- **Exclusion Filtering**: Excludes files by extension (global: `.tmp`, `.bak`, `.log`, `.dmp`, `.cache`, etc.) and regex patterns (per-server)
- **Compression**: Configurable compression with 7Zip4PowerShell (preferred) or built-in Compress-Archive (fallback)
  - Supports ZIP and 7z formats (7z is 10-30% smaller)
  - Compression levels: None, Fast, Low, Normal, High, Ultra
  - 7z format supports LZMA2 compression method for optimal game save compression
- **Temp Directory Strategy**: Creates temp dir, copies filtered files preserving structure, compresses, then deletes temp dir
- **Scheduling**: Backups only run during manual launches (not in scheduled task mode), respecting `$Global.BackupCheckFrequency` interval
- **Next Run Tracking**: Uses `servers\$ServerName.INI` to track when next backup should run

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
# Install/Update/Start a server
.\main.ps1 -ServerCfg "icarus"

# Run scheduled task checks (update/alive/restart checks)
.\main.ps1 -ServerCfg "icarus" -Task
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

## System Requirements

- Windows 10 or Windows Server 2016 or newer
- PowerShell 5.1 or higher
- User account should have admin privileges but **should not** run scripts elevated (as admin)
- Not recommended for primary gaming computers due to scheduled task popups (unless monitoring features are disabled)

**Common Game Server Dependencies** (may be required depending on game):
- DirectX End-User Runtime
- Microsoft Visual C++ Redistributable
- .NET Framework 4.8.1
- .NET Framework 5/6/7/8
- Java JDK (for Java-based servers)
- Microsoft XNA Redistributable

**Optional Performance Improvement**:
```powershell
Install-Module -Name 7Zip4Powershell  # Faster backup compression
```

## Key Configuration Files

- `global.psm1` - Global settings (paths to tools, check frequencies, colors, backup exclusions)
- `configs/*.psm1` - Server-specific configurations (copied from templates on first run)
- `servers/*.INI` - Task scheduling state (next backup/update/restart/alive times)
- `locks/*.lock` - Process lock files with timestamps to prevent concurrent execution

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

**Template Backup Pattern**:
- After applying settings from the .psm1 config to game files, create a `*_template.ini` or `*_template.lua` backup
- Only create template backup if it doesn't already exist (`if (-not (Test-Path $TemplateFile))`)
- This preserves the configured state as a reference and prevents overwriting user customizations

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

## Task Scheduler Integration

Tasks are created with:
- Daily trigger at midnight
- Repetition interval of 5 minutes (or `$Global.TaskCheckFrequency`)
- 3-hour execution time limit
- Hidden window execution
- Task name: `Tasks-$ServerName`

Tasks are automatically unregistered if all automation features (AutoUpdates, AutoRestartOnCrash, AutoRestart) are disabled.

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
3. Script creates Windows scheduled task for monitoring

This pause after installation is intentional - game servers require configuration before first start.

## Troubleshooting

**Errant Folder Creation**: If folders are created in unexpected locations (e.g., drive root), check path configuration:
- Verify `$Server.ConfigFolder` and `$Backups.Saves` use proper path patterns (see Path Resolution section)
- Common issue: missing `".\servers\"` prefix in relative paths

**Process Lock Issues**: If script reports "already running" when it's not:
- Check `.\locks\` folder for stale lock files
- Default timeout is 120 minutes; old locks are auto-removed after timeout
- Manual fix: delete the `.lock` file for the affected server

**Scheduled Task Popups**: Brief CMD window flashes every 5 minutes on desktop:
- Expected on workstations (not dedicated servers)
- Disable monitoring: Set `AutoUpdates`, `AutoRestartOnCrash`, and `AutoRestart` to `$false` in server config
- Or disable/delete the scheduled task in Windows Task Scheduler

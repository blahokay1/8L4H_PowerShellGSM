function Set-LuaValue {
    <#
    .SYNOPSIS
    Updates a value in a Lua table file

    .PARAMETER File
    Path to the .lua file

    .PARAMETER Table
    Name of the Lua table (e.g., "SandboxVars")

    .PARAMETER Key
    The key to update

    .PARAMETER Value
    The new value (handles strings, numbers, booleans)

    .EXAMPLE
    Set-LuaValue -File "config.lua" -Table "SandboxVars" -Key "Zombies" -Value 5

    .EXAMPLE
    Set-LuaValue -File "config.lua" -Table "Settings" -Key "ServerName" -Value "My Server"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$File,

        [Parameter(Mandatory=$true)]
        [string]$Table,

        [Parameter(Mandatory=$true)]
        [string]$Key,

        [Parameter(Mandatory=$true)]
        $Value
    )

    if (-not (Test-Path $File)) {
        Write-Warning "Lua file not found: $File"
        return
    }

    $content = Get-Content $File -Raw

    # Format value based on type
    $luaValue = if ($Value -is [bool]) {
        if ($Value) { "true" } else { "false" }
    } elseif ($Value -is [string]) {
        "`"$Value`""
    } else {
        $Value.ToString()
    }

    # Match pattern: "    Key = value," with any whitespace/comments
    # Handles both "Key = value," and "Key = value" (with/without trailing comma)
    $pattern = "(?m)^(\s+)$Key\s*=\s*[^,\n]+,?"
    $replacement = "`$1$Key = $luaValue,"

    if ($content -match $pattern) {
        $content = $content -replace $pattern, $replacement
        Set-Content -Path $File -Value $content -NoNewline
        Write-Verbose "Updated $Table.$Key = $luaValue"
    } else {
        Write-Warning "Key '$Key' not found in $Table"
    }
}

Export-ModuleMember -Function Set-LuaValue

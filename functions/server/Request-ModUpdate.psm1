function Request-ModUpdate {
  <#
  .SYNOPSIS
    Checks Steam Workshop for mod updates.
  .DESCRIPTION
    Queries the Steam Web API for the update timestamps of all Workshop mods
    configured in $Server.WorkshopItems. Compares against stored timestamps
    to detect if any mods have been updated since the last check.
  .OUTPUTS
    [boolean] $true if any mod has been updated, $false otherwise.
  #>

  # Parse Workshop IDs from semicolon-separated string
  if ([string]::IsNullOrEmpty($Server.WorkshopItems)) {
    Write-ServerMsg "No Workshop items configured, skipping mod update check."
    return $false
  }

  $WorkshopIDs = $Server.WorkshopItems -split ";" | Where-Object { $_ -ne "" }
  if ($WorkshopIDs.Count -eq 0) {
    Write-ServerMsg "No valid Workshop IDs found, skipping mod update check."
    return $false
  }

  Write-ServerMsg "Checking $($WorkshopIDs.Count) Workshop item(s) for updates..."

  # Build the Steam Web API POST request body
  $ApiUrl = "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/"
  $body = "itemcount=$($WorkshopIDs.Count)"
  for ($i = 0; $i -lt $WorkshopIDs.Count; $i++) {
    $body += "&publishedfileids[$i]=$($WorkshopIDs[$i])"
  }

  # Make the HTTP request
  $httpClient = $null
  try {
    $httpClient = New-Object System.Net.Http.HttpClient
    $httpClient.Timeout = [System.TimeSpan]::FromSeconds(30)

    $content = New-Object System.Net.Http.StringContent(
      $body,
      [System.Text.Encoding]::UTF8,
      "application/x-www-form-urlencoded"
    )

    $responseTask = $httpClient.PostAsync($ApiUrl, $content)
    $responseTask.Wait()

    if (-not $responseTask.Result.IsSuccessStatusCode) {
      Write-ServerMsg "Steam API returned status $($responseTask.Result.StatusCode), skipping mod update check."
      return $false
    }

    $readTask = $responseTask.Result.Content.ReadAsStringAsync()
    $readTask.Wait()
    $jsonResponse = $readTask.Result | ConvertFrom-Json
  }
  catch {
    Write-ServerMsg "Failed to query Steam Workshop API: $($_.Exception.Message)"
    Write-ServerMsg "Skipping mod update check (will retry next cycle)."
    return $false
  }
  finally {
    if ($httpClient) {
      $httpClient.Dispose()
    }
  }

  # Ensure the mod timestamps file path exists
  $ModTimestampFile = ".\servers\$($Server.Name)_ModTimestamps.INI"

  # Compare timestamps
  $UpdateDetected = $false

  foreach ($mod in $jsonResponse.response.publishedfiledetails) {
    $modId = $mod.publishedfileid
    $remoteTimestamp = $mod.time_updated

    # Skip mods that returned errors (e.g., removed from workshop)
    # result = 1 means success, anything else is an error
    if ($mod.result -ne 1) {
      Write-ServerMsg "Workshop item $modId returned error (result: $($mod.result)), skipping."
      continue
    }

    # Get stored timestamp for this mod
    $storedTimestamp = Get-IniValue -file $ModTimestampFile -category "ModTimestamps" -key $modId

    if ([string]::IsNullOrEmpty($storedTimestamp)) {
      # First time seeing this mod - store current timestamp, do not trigger update
      Write-ServerMsg "Workshop item $modId : First check, recording timestamp $remoteTimestamp"
      Set-IniValue -file $ModTimestampFile -category "ModTimestamps" -key $modId -value $remoteTimestamp
    }
    elseif ([int64]$remoteTimestamp -gt [int64]$storedTimestamp) {
      # Mod has been updated
      Write-ServerMsg "Workshop item $modId : Updated! (stored: $storedTimestamp, remote: $remoteTimestamp)"
      $UpdateDetected = $true
      # Update stored timestamp
      Set-IniValue -file $ModTimestampFile -category "ModTimestamps" -key $modId -value $remoteTimestamp
    }
    else {
      Write-ServerMsg "Workshop item $modId : Up to date"
    }
  }

  return $UpdateDetected
}

Export-ModuleMember -Function Request-ModUpdate

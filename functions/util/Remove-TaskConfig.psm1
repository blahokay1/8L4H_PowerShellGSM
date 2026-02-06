function Remove-TaskConfig {
  [CmdletBinding()]
  [OutputType([boolean])]
  param (
  )
  try {
    #Delete server watcher related files
    $null = Remove-Item -Path ".\servers\$($Server.Name)_ModTimestamps.INI" -Confirm:$false -ErrorAction SilentlyContinue
    $null = Remove-Item -Path ".\servers\$($Server.Name)_ServerWatcher.PID" -Confirm:$false -ErrorAction SilentlyContinue
    Write-ScriptMsg "Server watcher config removed."
  }
  catch {
    return $false
  }
  return $true
}
Export-ModuleMember -Function Remove-TaskConfig
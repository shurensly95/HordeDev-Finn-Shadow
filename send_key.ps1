Invoke-Expression @'
$wshell = New-Object -ComObject wscript.shell
$wshell.AppActivate('Diablo IV')
Start-Sleep -Seconds 1
if ($wshell.AppActivate('Diablo IV')) {
    Write-Output "Window activated"
    $wshell.SendKeys('{ENTER}')
    Write-Output "Enter key sent"
} else {
    Write-Output "Failed to activate window"
}
'@

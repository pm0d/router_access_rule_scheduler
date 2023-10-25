# Script to set schedule time in TP-Link W740N router
param (
    [Parameter(Position = 0)]
    [int]$minutesToAdd = 5, # Default to 5 minutes

    [Parameter(Position = 1)]
    [string]$schedule = "2" # Default to 2
)


function New-BasicAuthCookie {
    param (
        [string]$username,
        [string]$password
    )
    # Calculate the MD5 hash of the password
    $md5Hasher = [System.Security.Cryptography.MD5]::Create()
    $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($password)
    $passwordHashBytes = $md5Hasher.ComputeHash($passwordBytes)
    $passwordHashHex = [BitConverter]::ToString($passwordHashBytes) -replace '-', ''
    # Combine the username and password hash
    $combinedCredentials = "${username}:${passwordHashHex}".ToLower()
    # Base64 encode the combined credentials
    $base64Credentials = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($combinedCredentials))
    # URL encode the base64Credentials
    $base64Credentials = [System.Web.HttpUtility]::UrlEncode($base64Credentials)
    $cookieValue = "Authorization=Basic%20${base64Credentials}"
    return $cookieValue
}

function Get-RouterUrl {
    param (
        [string]$loginUrl,
        [string]$authCookie
    )
    
    $htmloutput = curl -s -X GET $loginUrl -H "Cookie: $authCookie"
    $match = $htmloutput | Select-String -Pattern 'window\.parent\.location\.href\s*=\s*"([^"]+)"'
    if ($match) {
        $url = $match.Matches.Groups[1].Value
        Write-Host
        Write-Host -ForegroundColor 13 "Connected to $url" 
        $uri = [System.Uri]$url
        if ($uri.Segments[-3] -ne $null) {
            $urlSegment = $uri.Segments[-3].TrimEnd('/')
            return $urlSegment
        }
        else {
            Write-Host -ForegroundColor Red "Failed to connect to router. Please retry."
            exit
        }
    }
    else {
        Write-Host -ForegroundColor Red "Failed to connect to router. Please check the username and password."
        exit
    }
}

function Update-Schedule {
    param (
        [string]$urlSegment,
        [string]$authCookie,
        [string]$schedule,
        [int]$minutesToAdd
    )
    # Get the current time and add specified number of minutes 
    $currentTime = Get-Date
    $endTime = $currentTime.AddMinutes($minutesToAdd)
    # $endTimeStr = $endTime.ToString("HH:mm")
    $endTime = $endTime.ToString("HHmm")
    $currentTime = $currentTime.ToString("HHmm")
    $scheduleUrl = "http://192.168.0.1/$urlSegment/userRpm/AccessCtrlTimeSchedRpm.htm?time_sched_name=Schedule+$schedule&day_type=1&time_sched_start_time=$currentTime&time_sched_end_time=$endTime&Changed=1&SelIndex=$($schedule-1)&fromAdd=0&Page=1&Save=Save"
    
    # Determine which schedule to use based on the parameter
    if ($schedule -eq "1" -or $schedule -eq "2") {
        $htmloutput = curl -s -X GET $scheduleUrl -H "Referer: http://192.168.0.1/" -H "Cookie: $authCookie"
        # Write-Host "Schedule $schedule ends at $endTimeStr... http://192.168.0.1/$urlSegment/userRpm/AccessCtrlTimeSchedRpm.htm"
        Write-Host
        $htmloutput = curl -s -X GET "http://192.168.0.1/$urlSegment/userRpm/AccessCtrlTimeSchedRpm.htm" -H "Cookie: $authCookie" -H "Referer: http://192.168.0.1/$urlSegment/userRpm/MenuRpm.htm"
        # $match = $htmloutput | Select-String -Pattern 'window\.parent\.location\.href\s*=\s*"([^"]+)"'
        $schedList = $htmloutput.Split("`n")[2] + "`n" + $htmloutput.Split("`n")[3]
        Write-Host $schedList
        Write-Host
    }
    else {
        Write-Host -ForegroundColor Red  "Invalid schedule. The value for schedule parameter should be '1' or '2'."
    }
}


# Specify username, password and router login page
$username = "admin"
$password = "admin"
$loginUrl = "http://192.168.0.1/userRpm/LoginRpm.htm?Save=Save"

# Create auth cookie, log in to the router and update schedule
$authCookie = New-BasicAuthCookie -username $username -password $password
$urlSegment = Get-RouterUrl -loginUrl $loginUrl -authCookie $authCookie
Update-Schedule -urlSegment $urlSegment -authCookie $authCookie -schedule $schedule -minutesToAdd $minutesToAdd

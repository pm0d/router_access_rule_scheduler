# Script to set schedule time on the TP-Link TL-WR740N router

param (
    [string]$schedule = "1" # Default to use Schedule 1 defined in the router 
)

function Create-BasicAuthCookie {
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

# Specify username, password and router login page
$username = "admin"
$password = "admin"
$loginUrl = "http://192.168.0.1/userRpm/LoginRpm.htm?Save=Save"

# Create auth cookie and log in to the router 
$authCookie = Create-BasicAuthCookie -username $username -password $password
$htmloutput = curl -s -X GET $loginUrl -H "Cookie: $authCookie"
$match = $htmloutput | Select-String -Pattern 'window\.parent\.location\.href\s*=\s*"([^"]+)"'
if ($match) {
    $url = $match.Matches.Groups[1].Value
    Write-Host
    Write-Host -ForegroundColor 13 "Connected to $url" 
    $uri = [System.Uri]$url
    $urlSegment = $uri.Segments[-3].TrimEnd('/')
}

# Get the current time and add specified number of minutes 
$currentTime = Get-Date
$endTime = $currentTime.AddMinutes(5)
$endTimeStr = $endTime.ToString("HH:mm")
$endTime = $endTime.ToString("HHmm")
$currentTime = $currentTime.ToString("HHmm")

$schedule1 = "http://192.168.0.1/" + $urlSegment + "/userRpm/AccessCtrlTimeSchedRpm.htm?time_sched_name=Schedule+1&day_type=1&time_sched_start_time=" + $currentTime + "&time_sched_end_time=" + $endTime + "&Changed=1&SelIndex=0&fromAdd=0&Page=1&Save=Save"
$schedule2 = "http://192.168.0.1/" + $urlSegment + "/userRpm/AccessCtrlTimeSchedRpm.htm?time_sched_name=Schedule+2&day_type=1&time_sched_start_time=" + $currentTime + "&time_sched_end_time=" + $endTime + "&Changed=1&SelIndex=1&fromAdd=0&Page=1&Save=Save"

# Determine which schedule to use based on the parameter
if ($schedule -eq "1") {
    $scheduleUrl = $schedule1
}
elseif ($schedule -eq "2") {
    $scheduleUrl = $schedule2
}
else {
    Write-Host "Invalid schedule name specified. Please use '1' or '2' as the parameter."
    exit
}

$htmloutput = curl -s -X GET $scheduleUrl -H "Referer: http://192.168.0.1/" -H "Cookie: $authCookie"
Write-Host "Schedule $schedule ends at $endTimeStr ..."
Write-Host

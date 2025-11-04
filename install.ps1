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
    [string]$ConfigDir = "$env:APPDATA\kmonad"
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

# Check if KMonad executable exists
if (-not (Test-Path $KMonadPath)) {
    Write-Host "KMonad executable not found at: $KMonadPath" -ForegroundColor Red
    
    # Try common alternative locations
    $alternativePaths = @(
        "$env:APPDATA\Local\bin\kmonad.exe",
        "$env:LOCALAPPDATA\bin\kmonad.exe"
    )
    
    $found = $false
    foreach ($altPath in $alternativePaths) {
        if (Test-Path $altPath) {
            Write-Host "Found KMonad at: $altPath" -ForegroundColor Green
            $KMonadPath = $altPath
            $found = $true
            break
        }
    }
    
    if (-not $found) {
        $newPath = Read-Host "Please enter the full path to kmonad.exe"
        if (-not (Test-Path $newPath)) {
            Write-Error "KMonad executable not found at: $newPath"
            exit 1
        }
        $KMonadPath = $newPath
    }
}

# Get service name suffix
$serviceNameSuffix = Get-ServiceNameSuffix
$serviceName = "KMonad-$serviceNameSuffix"
$configName = "config-$serviceNameSuffix.kbd"

Write-Host "Service will be created as: $serviceName" -ForegroundColor Yellow

# Show keyboard devices for reference
Show-KeyboardDevices

# Create config directory
if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    Write-Host "Created config directory: $ConfigDir" -ForegroundColor Green
}

# Create Windows-specific configuration file
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$windowsConfigPath = Join-Path $scriptDir "config-windows.kbd"
$linuxConfigPath = Join-Path $scriptDir "config.kbd"

$configPath = Join-Path $ConfigDir $configName

if (Test-Path $windowsConfigPath) {
    # Use the Windows-specific config
    Copy-Item -Path $windowsConfigPath -Destination $configPath -Force
    Write-Host "Created Windows config file from template: $configPath" -ForegroundColor Green
} elseif (Test-Path $linuxConfigPath) {
    # Convert Linux config to Windows format
    $configContent = Get-Content $linuxConfigPath -Raw
    
    # Replace Linux-specific parts with Windows equivalents
    $windowsConfig = $configContent -replace 'input \(device-file "[^"]*"\)', 'input (low-level-hook)'
    $windowsConfig = $windowsConfig -replace 'output \(uinput-sink[^)]*\)', 'output (send-event-sink)'
    $windowsConfig = $windowsConfig -replace '\$INPUT_DEVICE_FILE', 'low-level-hook'
    
    $windowsConfig | Out-File -FilePath $configPath -Encoding UTF8
    Write-Host "Created Windows config file from Linux template: $configPath" -ForegroundColor Green
} else {
    Write-Error "No config template found. Expected config-windows.kbd or config.kbd"
    exit 1
}

# Create service using NSSM (Non-Sucking Service Manager) approach or direct service registration
# First, try to create service directly, then fall back to scheduled task if needed

# Check if service already exists and remove it
$existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Removing existing service: $serviceName" -ForegroundColor Yellow
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    & sc.exe delete $serviceName
    Start-Sleep -Seconds 3
}

# Try creating the service directly with KMonad executable
Write-Host "Creating Windows service: $serviceName" -ForegroundColor Green

# Use the full command line as the binPath
$binPath = "`"$KMonadPath`" `"$configPath`""

$scResult = & sc.exe create $serviceName `
    binPath= $binPath `
    start= auto `
    DisplayName= "KMonad Keyboard Remapper ($serviceNameSuffix)" `
    depend= "Winmgmt"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Service created successfully!" -ForegroundColor Green
    
    # Set service description
    & sc.exe description $serviceName "KMonad keyboard remapper service for enhanced keyboard functionality"
    
    # Configure service to restart on failure
    & sc.exe failure $serviceName reset= 86400 actions= restart/5000/restart/5000/restart/5000
    
    # Try to start the service
    Write-Host "Starting service..." -ForegroundColor Yellow
    
    try {
        $startResult = Start-Service -Name $serviceName -PassThru -ErrorAction Stop
        if ($startResult -and $startResult.Status -eq "Running") {
            Write-Host "Service started successfully!" -ForegroundColor Green
            $serviceSuccess = $true
        }
    }
    catch {
        Write-Warning "Service created but failed to start: $($_.Exception.Message)"
        Write-Host "This is often due to KMonad requiring interactive desktop access." -ForegroundColor Yellow
        $serviceSuccess = $false
    }
    
    if (-not $serviceSuccess) {
        Write-Host "Removing the service and creating a scheduled task instead..." -ForegroundColor Yellow
        & sc.exe delete $serviceName
        
        # Create a scheduled task instead
        $taskName = "KMonad-$serviceNameSuffix"
        
        # Remove existing task if it exists
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }
        
        # Create the scheduled task
        $action = New-ScheduledTaskAction -Execute $KMonadPath -Argument "`"$configPath`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "KMonad keyboard remapper for enhanced keyboard functionality"
        
        Write-Host "Created scheduled task: $taskName" -ForegroundColor Green
        Write-Host "KMonad will start automatically when you log in." -ForegroundColor Green
        
        # Try to start the task
        Start-ScheduledTask -TaskName $taskName
        Write-Host "Started scheduled task." -ForegroundColor Green
        
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
    Write-Error "Failed to create service. Error code: $LASTEXITCODE"
    Write-Host "Output: $scResult" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Installation completed!" -ForegroundColor Green
Write-Host "Note: You may need to restart your computer for all changes to take effect." -ForegroundColor Yellow
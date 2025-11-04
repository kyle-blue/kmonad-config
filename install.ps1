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

# Function to get keyboard device
function Get-KeyboardDevice {
    Write-Host "Available keyboard devices:" -ForegroundColor Green
    $keyboards = Get-PnpDevice -Class "Keyboard" -Status "OK" | Select-Object FriendlyName, InstanceId
    
    for ($i = 0; $i -lt $keyboards.Count; $i++) {
        Write-Host "[$i] $($keyboards[$i].FriendlyName)" -ForegroundColor Yellow
    }
    
    do {
        $selection = Read-Host "Select keyboard device by number (0-$($keyboards.Count - 1))"
        if ($selection -match '^\d+$' -and [int]$selection -ge 0 -and [int]$selection -lt $keyboards.Count) {
            return $keyboards[[int]$selection].InstanceId
        }
        Write-Host "Invalid selection. Please enter a number between 0 and $($keyboards.Count - 1)." -ForegroundColor Red
    } while ($true)
}

# Check if running as administrator
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

# Get keyboard device
$keyboardDevice = Get-KeyboardDevice
Write-Host "Selected keyboard device: $keyboardDevice" -ForegroundColor Yellow

# Create config directory
if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    Write-Host "Created config directory: $ConfigDir" -ForegroundColor Green
}

# Create Windows-specific configuration file
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$linuxConfigPath = Join-Path $scriptDir "config.kbd"

if (Test-Path $linuxConfigPath) {
    $configContent = Get-Content $linuxConfigPath -Raw
    
    # Replace Linux-specific parts with Windows equivalents
    $windowsConfig = $configContent -replace '\$INPUT_DEVICE_FILE', "device-file `"$keyboardDevice`""
    $windowsConfig = $windowsConfig -replace 'input \(device-file "\$INPUT_DEVICE_FILE"\)', "input (device-file `"$keyboardDevice`")"
    $windowsConfig = $windowsConfig -replace 'output \(uinput-sink "KMonad Keychron K3"[^)]*\)', 'output (send-event-sink)'
    
    $configPath = Join-Path $ConfigDir $configName
    $windowsConfig | Out-File -FilePath $configPath -Encoding UTF8
    Write-Host "Created Windows config file: $configPath" -ForegroundColor Green
} else {
    Write-Error "Source config file not found: $linuxConfigPath"
    exit 1
}

# Create service wrapper script
$wrapperScript = @"
@echo off
cd /d "$ConfigDir"
"$KMonadPath" "$configPath"
"@

$wrapperPath = Join-Path $ConfigDir "kmonad-service-$serviceNameSuffix.bat"
$wrapperScript | Out-File -FilePath $wrapperPath -Encoding ASCII
Write-Host "Created service wrapper: $wrapperPath" -ForegroundColor Green

# Check if service already exists and remove it
$existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Removing existing service: $serviceName" -ForegroundColor Yellow
    Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
    & sc.exe delete $serviceName
    Start-Sleep -Seconds 2
}

# Create the Windows service using sc.exe
Write-Host "Creating Windows service: $serviceName" -ForegroundColor Green

$scResult = & sc.exe create $serviceName `
    binPath= "`"$wrapperPath`"" `
    start= auto `
    DisplayName= "KMonad Keyboard Remapper ($serviceNameSuffix)" `
    depend= "Winmgmt"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Service created successfully!" -ForegroundColor Green
    
    # Set service description
    & sc.exe description $serviceName "KMonad keyboard remapper service for enhanced keyboard functionality"
    
    # Configure service to restart on failure
    & sc.exe failure $serviceName reset= 86400 actions= restart/5000/restart/5000/restart/5000
    
    # Start the service
    Write-Host "Starting service..." -ForegroundColor Yellow
    $startResult = Start-Service -Name $serviceName -PassThru -ErrorAction SilentlyContinue
    
    if ($startResult -and $startResult.Status -eq "Running") {
        Write-Host "Service started successfully!" -ForegroundColor Green
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
    } else {
        Write-Warning "Service created but failed to start. You may need to check the configuration."
        Write-Host "Try starting manually with: Start-Service -Name '$serviceName'" -ForegroundColor Yellow
    }
} else {
    Write-Error "Failed to create service. Error code: $LASTEXITCODE"
    Write-Host "Output: $scResult" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Installation completed!" -ForegroundColor Green
Write-Host "Note: You may need to restart your computer for all changes to take effect." -ForegroundColor Yellow
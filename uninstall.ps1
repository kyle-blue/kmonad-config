<#
.SYNOPSIS
    Uninstall KMonad
.DESCRIPTION
    This script removes KMonad startup shortcuts and cleans up configuration files.
#>

param(
    [switch]$RemoveAllConfigs = $false
)

# Function to get current GUI logged-in user
function Get-CurrentGUIUser {
    try {
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        if ($computerSystem.UserName) {
            return ($computerSystem.UserName -split '\\')[-1]
        }
    } catch {
        # Fallback to current user
        return $env:USERNAME
    }
}

Write-Host "KMonad Uninstaller" -ForegroundColor Red
Write-Host "==================" -ForegroundColor Red

# Get current user
$currentUser = Get-CurrentGUIUser
$userProfile = "C:\Users\$currentUser"
$configDir = Join-Path $userProfile "AppData\Roaming\kmonad"
$startupFolder = Join-Path $userProfile "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
$shortcutPath = Join-Path $startupFolder "KMonad.lnk"

Write-Host "Uninstalling for user: $currentUser" -ForegroundColor Yellow
Write-Host ""

# Stop KMonad process if running
$kmonadProcess = Get-Process -Name "kmonad" -ErrorAction SilentlyContinue
if ($kmonadProcess) {
    Write-Host "Found running KMonad process(es), stopping..." -ForegroundColor Yellow
    Stop-Process -Name "kmonad" -Force
    Write-Host "  Stopped KMonad process" -ForegroundColor Green
} else {
    Write-Host "No running KMonad process found." -ForegroundColor Yellow
}

# Remove startup shortcut
if (Test-Path $shortcutPath) {
    Write-Host "Removing startup shortcut: $shortcutPath" -ForegroundColor Yellow
    try {
        Remove-Item -Path $shortcutPath -Force
        Write-Host "  Removed startup shortcut" -ForegroundColor Green
    } catch {
        Write-Warning "  Failed to remove startup shortcut: $($_.Exception.Message)"
    }
} else {
    Write-Host "No startup shortcut found." -ForegroundColor Yellow
}

# Handle configuration cleanup
if (Test-Path $configDir) {
    Write-Host ""
    Write-Host "Configuration directory found: $configDir" -ForegroundColor Yellow
    
    $configFiles = Get-ChildItem -Path $configDir -Filter "*.kbd" -ErrorAction SilentlyContinue
    $vbsFiles = Get-ChildItem -Path $configDir -Filter "*.vbs" -ErrorAction SilentlyContinue
    
    if ($configFiles.Count -gt 0 -or $vbsFiles.Count -gt 0) {
        Write-Host "Found configuration files:"
        foreach ($file in $configFiles) {
            Write-Host "  - $($file.Name)" -ForegroundColor White
        }
        foreach ($file in $vbsFiles) {
            Write-Host "  - $($file.Name)" -ForegroundColor White
        }
        
        if ($RemoveAllConfigs) {
            $removeConfigs = 'y'
        } else {
            $removeConfigs = Read-Host "Do you want to remove configuration files? (y/N)"
        }
        
        if ($removeConfigs -eq 'y' -or $removeConfigs -eq 'Y') {
            foreach ($file in $configFiles) {
                Remove-Item -Path $file.FullName -Force
                Write-Host "  Removed: $($file.Name)" -ForegroundColor Green
            }
            foreach ($file in $vbsFiles) {
                Remove-Item -Path $file.FullName -Force
                Write-Host "  Removed: $($file.Name)" -ForegroundColor Green
            }
            
            # Remove directory if empty
            $remainingFiles = Get-ChildItem -Path $configDir -ErrorAction SilentlyContinue
            if ($remainingFiles.Count -eq 0) {
                Remove-Item -Path $configDir -Force
                Write-Host "  Removed empty config directory" -ForegroundColor Green
            }
        } else {
            Write-Host "Configuration files kept." -ForegroundColor Yellow
        }
    } else {
        Write-Host "No KMonad configuration files found in config directory." -ForegroundColor Yellow
    }
} else {
    Write-Host "Configuration directory not found." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Uninstallation completed!" -ForegroundColor Green
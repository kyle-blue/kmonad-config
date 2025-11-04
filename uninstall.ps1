#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Uninstall KMonad Windows services
.DESCRIPTION
    This script removes KMonad services and cleans up configuration files.
.NOTES
    This script must be run as Administrator
#>

param(
    [string]$ConfigDir = "$env:APPDATA\kmonad",
    [switch]$RemoveAllConfigs = $false
)

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if running as administrator
if (-not (Test-Administrator)) {
    Write-Error "This script must be run as Administrator. Please restart PowerShell as Administrator and try again."
    exit 1
}

Write-Host "KMonad Windows Service Uninstaller" -ForegroundColor Red
Write-Host "===================================" -ForegroundColor Red

# Find all KMonad services and scheduled tasks
$kmonadServices = Get-Service -Name "KMonad-*" -ErrorAction SilentlyContinue
$kmonadTasks = Get-ScheduledTask -TaskName "KMonad-*" -ErrorAction SilentlyContinue

if ($kmonadServices.Count -eq 0 -and $kmonadTasks.Count -eq 0) {
    Write-Host "No KMonad services or scheduled tasks found." -ForegroundColor Yellow
} else {
    if ($kmonadServices.Count -gt 0) {
        Write-Host "Found $($kmonadServices.Count) KMonad service(s):" -ForegroundColor Yellow
        foreach ($service in $kmonadServices) {
            Write-Host "  - $($service.Name) ($($service.Status))" -ForegroundColor White
        }
    }
    
    if ($kmonadTasks.Count -gt 0) {
        Write-Host "Found $($kmonadTasks.Count) KMonad scheduled task(s):" -ForegroundColor Yellow
        foreach ($task in $kmonadTasks) {
            Write-Host "  - $($task.TaskName) ($($task.State))" -ForegroundColor White
        }
    }
    
    $confirmation = Read-Host "Do you want to remove all KMonad services and scheduled tasks? (y/N)"
    if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
        # Remove services
        foreach ($service in $kmonadServices) {
            Write-Host "Stopping and removing service: $($service.Name)" -ForegroundColor Yellow
            
            # Stop the service if running
            if ($service.Status -eq "Running") {
                Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
                Write-Host "  Stopped service" -ForegroundColor Green
            }
            
            # Remove the service
            $deleteResult = & sc.exe delete $service.Name
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Removed service successfully" -ForegroundColor Green
            } else {
                Write-Warning "  Failed to remove service: $deleteResult"
            }
        }
        
        # Remove scheduled tasks
        foreach ($task in $kmonadTasks) {
            Write-Host "Stopping and removing scheduled task: $($task.TaskName)" -ForegroundColor Yellow
            
            # Stop the task if running
            if ($task.State -eq "Running") {
                Stop-ScheduledTask -TaskName $task.TaskName -ErrorAction SilentlyContinue
                Write-Host "  Stopped task" -ForegroundColor Green
            }
            
            # Remove the task
            try {
                Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
                Write-Host "  Removed scheduled task successfully" -ForegroundColor Green
            }
            catch {
                Write-Warning "  Failed to remove scheduled task: $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "Removal cancelled." -ForegroundColor Yellow
    }
}

# Handle configuration cleanup
if (Test-Path $ConfigDir) {
    Write-Host ""
    Write-Host "Configuration directory found: $ConfigDir" -ForegroundColor Yellow
    
    $configFiles = Get-ChildItem -Path $ConfigDir -Filter "*.kbd" -ErrorAction SilentlyContinue
    
    if ($configFiles.Count -gt 0) {
        Write-Host "Found configuration files:"
        foreach ($file in $configFiles) {
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
            
            # Remove directory if empty
            $remainingFiles = Get-ChildItem -Path $ConfigDir -ErrorAction SilentlyContinue
            if ($remainingFiles.Count -eq 0) {
                Remove-Item -Path $ConfigDir -Force
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
Write-Host "You may want to restart your computer to ensure all changes take effect." -ForegroundColor Yellow
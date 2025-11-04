#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Test KMonad configuration and troubleshoot issues
.DESCRIPTION
    This script helps test KMonad configurations and diagnose common problems.
.NOTES
    This script should be run as Administrator for proper testing
#>

param(
    [string]$KMonadPath = "C:\Program Files\kmonad\kmonad.exe",
    [string]$ConfigDir = "$env:APPDATA\kmonad"
)

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-KMonadConfiguration {
    param([string]$ConfigPath)
    
    Write-Host "Testing KMonad configuration: $ConfigPath" -ForegroundColor Yellow
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "  ❌ Config file not found" -ForegroundColor Red
        return $false
    }
    
    Write-Host "  ✅ Config file exists" -ForegroundColor Green
    
    # Test KMonad with dry-run (if supported) or short run
    try {
        Write-Host "  Testing KMonad startup..." -ForegroundColor Yellow
        $process = Start-Process -FilePath $KMonadPath -ArgumentList "`"$ConfigPath`"" -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 3
        
        if (-not $process.HasExited) {
            Write-Host "  ✅ KMonad started successfully" -ForegroundColor Green
            $process.Kill()
            return $true
        } else {
            Write-Host "  ❌ KMonad exited immediately (exit code: $($process.ExitCode))" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "  ❌ Failed to start KMonad: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Check if running as administrator
if (-not (Test-Administrator)) {
    Write-Warning "This script should be run as Administrator for accurate testing."
}

Write-Host "KMonad Configuration Tester" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

# Check KMonad executable
Write-Host "Checking KMonad executable..." -ForegroundColor Yellow
if (Test-Path $KMonadPath) {
    Write-Host "  ✅ KMonad found at: $KMonadPath" -ForegroundColor Green
    
    # Get version info
    try {
        $versionInfo = & $KMonadPath --version 2>$null
        if ($versionInfo) {
            Write-Host "  ✅ Version: $versionInfo" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ⚠️  Could not get version info" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ KMonad not found at: $KMonadPath" -ForegroundColor Red
    
    # Try to find KMonad in common locations
    $commonPaths = @(
        "$env:LOCALAPPDATA\bin\kmonad.exe",
        "$env:APPDATA\Local\bin\kmonad.exe",
        ".\kmonad.exe"
    )
    
    $found = $false
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            Write-Host "  ✅ Found KMonad at: $path" -ForegroundColor Green
            $KMonadPath = $path
            $found = $true
            break
        }
    }
    
    if (-not $found) {
        Write-Host "  Please specify the correct path to kmonad.exe" -ForegroundColor Red
        $newPath = Read-Host "Enter path to kmonad.exe (or press Enter to skip)"
        if (-not [string]::IsNullOrEmpty($newPath) -and (Test-Path $newPath)) {
            $KMonadPath = $newPath
            $found = $true
        }
    }
    
    if (-not $found) {
        Write-Host "Cannot continue without KMonad executable." -ForegroundColor Red
        exit 1
    }
}

# Check config directory
Write-Host ""
Write-Host "Checking configuration directory..." -ForegroundColor Yellow
if (Test-Path $ConfigDir) {
    Write-Host "  ✅ Config directory exists: $ConfigDir" -ForegroundColor Green
    
    # List config files
    $configFiles = Get-ChildItem -Path $ConfigDir -Filter "*.kbd"
    if ($configFiles.Count -gt 0) {
        Write-Host "  ✅ Found $($configFiles.Count) config file(s):" -ForegroundColor Green
        foreach ($file in $configFiles) {
            Write-Host "    - $($file.Name)" -ForegroundColor White
        }
        
        # Test each config
        Write-Host ""
        Write-Host "Testing configurations..." -ForegroundColor Yellow
        foreach ($file in $configFiles) {
            Test-KMonadConfiguration -ConfigPath $file.FullName
        }
    } else {
        Write-Host "  ⚠️  No .kbd config files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ Config directory not found: $ConfigDir" -ForegroundColor Red
}

# Check services and scheduled tasks
Write-Host ""
Write-Host "Checking KMonad services and tasks..." -ForegroundColor Yellow

$services = Get-Service -Name "KMonad-*" -ErrorAction SilentlyContinue
$tasks = Get-ScheduledTask -TaskName "KMonad-*" -ErrorAction SilentlyContinue

if ($services.Count -gt 0) {
    Write-Host "  ✅ Found $($services.Count) service(s):" -ForegroundColor Green
    foreach ($service in $services) {
        $status = if ($service.Status -eq "Running") { "✅" } else { "⚠️" }
        Write-Host "    $status $($service.Name) - $($service.Status)" -ForegroundColor White
    }
}

if ($tasks.Count -gt 0) {
    Write-Host "  ✅ Found $($tasks.Count) scheduled task(s):" -ForegroundColor Green
    foreach ($task in $tasks) {
        $status = if ($task.State -eq "Running") { "✅" } else { "⚠️" }
        Write-Host "    $status $($task.TaskName) - $($task.State)" -ForegroundColor White
    }
}

if ($services.Count -eq 0 -and $tasks.Count -eq 0) {
    Write-Host "  ⚠️  No KMonad services or scheduled tasks found" -ForegroundColor Yellow
    Write-Host "    Run install.ps1 to set up KMonad" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Testing completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Common troubleshooting steps:" -ForegroundColor Cyan
Write-Host "1. Ensure KMonad.exe is the correct Windows version" -ForegroundColor White
Write-Host "2. Check that config uses (low-level-hook) for input" -ForegroundColor White
Write-Host "3. Check that config uses (send-event-sink) for output" -ForegroundColor White
Write-Host "4. Run as Administrator when testing" -ForegroundColor White
Write-Host "5. Temporarily disable antivirus if KMonad is blocked" -ForegroundColor White
<#
.SYNOPSIS
Automates capturing network traffic to/from Reddit.com 30 times using tshark.

.DESCRIPTION
This script loops 30 times. In each iteration, it starts a tshark capture,
opens Reddit.com in the default browser, captures for a specified duration,
saves the capture, converts it to CSV, and cleans up temporary files.
Requires Wireshark installed and administrator privileges.

.NOTES
Author: AI Assistant
Date:   2025-05-04
Ensure Wireshark is installed and you know your Wi-Fi interface number/GUID.
Run this script as Administrator.
You might need to adjust PowerShell Execution Policy (e.g., Set-ExecutionPolicy RemoteSigned -Scope Process)
#>

# --- Configuration ---
$wiresharkPath = "C:\Program Files\Wireshark" # IMPORTANT: Verify this path exists or update it!
$tsharkExe = Join-Path $wiresharkPath "tshark.exe"
$numberOfCaptures = 30
$captureDurationSeconds = 20 # Duration of each capture in seconds
$delayBetweenCapturesSeconds = 10 # Wait time before starting the next capture

# --- User Input ---
Write-Host "--- Network Capture Configuration ---" -ForegroundColor Yellow

# Check if tshark exists
if (-not (Test-Path $tsharkExe)) {
    Write-Host "Error: tshark.exe not found at '$tsharkExe'." -ForegroundColor Red
    Write-Host "Please verify the Wireshark installation path in the script." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    Exit 1
}

# Get Network Interface
Write-Host "Listing available network interfaces..."
# Ensure we are in the Wireshark directory or tshark is in PATH for -D to work easily
Push-Location $wiresharkPath
try {
    .\tshark.exe -D
} finally {
    Pop-Location
}
$interfaceNumber = Read-Host "Enter the NUMBER of your Wi-Fi interface from the list above"

# Validate interface number (basic check)
if ($interfaceNumber -notmatch '^\d+$') {
    Write-Host "Error: Invalid interface number entered. Please enter only the number." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    Exit 1
}

# Get Output Directory
$defaultOutputDir = Join-Path $env:USERPROFILE "Documents\RedditCaptures"
$outputDirectory = Read-Host "Enter the directory to save CSV captures (Default: $defaultOutputDir)"
if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
    $outputDirectory = $defaultOutputDir
}

# Create Output Directory if it doesn't exist
if (-not (Test-Path $outputDirectory)) {
    Write-Host "Creating output directory: $outputDirectory" -ForegroundColor Cyan
    try {
        New-Item -ItemType Directory -Path $outputDirectory -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "Error: Could not create output directory ' $outputDirectory'. Check permissions or path." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Read-Host "Press Enter to exit"
        Exit 1
    }
}

Write-Host "--- Configuration Summary ---" -ForegroundColor Green
Write-Host "tshark path: $tsharkExe"
Write-Host "Interface Number: $interfaceNumber"
Write-Host "Output Directory: $outputDirectory"
Write-Host "Number of Captures: $numberOfCaptures"
Write-Host "Capture Duration: $captureDurationSeconds seconds"
Write-Host "-----------------------------"
Read-Host "Press Enter to start the capture process (ensure no sensitive Browse occurs during capture)"

# --- Capture Loop ---
for ($i = 1; $i -le $numberOfCaptures; $i++) {
    Write-Host "`n--- Starting Capture $i of $numberOfCaptures ---" -ForegroundColor Yellow

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $tempPcapFile = Join-Path $outputDirectory "temp_reddit_capture_${timestamp}_${i}.pcapng"
    $outputCsvFile = Join-Path $outputDirectory "reddit_capture_${timestamp}_${i}.csv"

    # Define tshark arguments for capture
    $captureArgs = @(
        "-i", $interfaceNumber,              # Interface number
        "-a", "duration:$captureDurationSeconds", # Stop after X seconds
        "-w", $tempPcapFile                  # Output raw capture file
        # Optional: Add a capture filter here if desired, e.g., "-f", "tcp port 443 or tcp port 80"
        # Be cautious with capture filters - they might miss related traffic (like DNS on port 53)
        # Capturing all traffic on the interface for the duration is often safer for automation.
    )

    # Define tshark arguments for CSV conversion
    $convertArgs = @(
        "-r", $tempPcapFile,                # Input raw capture file
        "-T", "fields",                     # Output format: fields
        "-e", "frame.number",               # Field: Frame Number
        "-e", "frame.time_epoch",           # Field: Timestamp (Epoch)
        "-e", "ip.src",                     # Field: Source IP
        "-e", "ip.dst",                     # Field: Destination IP
        "-e", "tcp.srcport",                # Field: TCP Source Port
        "-e", "tcp.dstport",                # Field: TCP Dest Port
        "-e", "udp.srcport",                # Field: UDP Source Port
        "-e", "udp.dstport",                # Field: UDP Dest Port
        "-e", "_ws.col.Protocol",           # Field: Protocol (Wireshark column)
        "-e", "frame.len",                  # Field: Frame Length
        "-e", "_ws.col.Info",               # Field: Info (Wireshark column)
        "-E", "header=y",                   # Include header row
        "-E", "separator=,"                 # Use comma as separator
        # "-E", "quote=d"                   # Optional: Use double quotes around fields
    )

    Write-Host "[$($i)] $(Get-Date -Format HH:mm:ss): Starting capture..."

    # Start tshark capture process in the background
    $captureProcess = Start-Process -FilePath $tsharkExe -ArgumentList $captureArgs -PassThru -WindowStyle Hidden # Use Minimized if Hidden causes issues

    # Wait a moment for capture to initialize
    Start-Sleep -Seconds 3

    # Trigger Reddit traffic
    Write-Host "[$($i)] $(Get-Date -Format HH:mm:ss): Opening Reddit.com..."
    try {
        Start-Process "https://www.reddit.com" -ErrorAction Stop
    } catch {
        Write-Host "Warning: Could not automatically open Reddit.com. Please open it manually." -ForegroundColor Magenta
        Write-Host $_.Exception.Message -ForegroundColor Magenta
    }

    # Wait for the capture duration + a little buffer
    $waitTime = $captureDurationSeconds + 2
    Write-Host "[$($i)] $(Get-Date -Format HH:mm:ss): Capturing for $captureDurationSeconds seconds..."
    Start-Sleep -Seconds $waitTime

    # Check if capture process finished (it should have due to -a duration)
    # If it's still running for some reason, stop it (unlikely but for safety)
    if ($captureProcess -and (-not $captureProcess.HasExited)) {
         Write-Host "[$($i)] $(Get-Date -Format HH:mm:ss): Capture duration elapsed, ensuring process stopped." -ForegroundColor Magenta
         Stop-Process -Id $captureProcess.Id -Force -ErrorAction SilentlyContinue
    } else {
         Write-Host "[$($i)] $(Get-Date -Format HH:mm:ss): Capture finished."
    }

    # Convert the capture to CSV
    if (Test-Path $tempPcapFile) {
        Write-Host "[$($i)] $(Get-Date -Format HH:mm:ss): Converting '$tempPcapFile' to '$outputCsvFile'..."
        try {
            # Use Invoke-Expression to handle the redirection '>' properly in PowerShell
            $command = "& `"$tsharkExe`" $($convertArgs -join ' ') > `"$outputCsvFile`""
            Invoke-Expression $command
            Write-Host "[$($i)] $(Get-Date -Format HH:mm:ss): Conversion successful." -ForegroundColor Green

            # Clean up the temporary pcapng file
            Write-Host "[$($i)] $(Get-Date -Format HH:mm:ss): Removing temporary file '$tempPcapFile'..."
            Remove-Item -Path $tempPcapFile -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Host "Error during conversion or cleanup for capture $i." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            # Keep the temp pcapng file for manual inspection if conversion fails
            Write-Host "Temporary file '$tempPcapFile' was NOT deleted due to error." -ForegroundColor Magenta
        }
    } else {
        Write-Host "Error: Temporary capture file '$tempPcapFile' not found. Capture might have failed." -ForegroundColor Red
    }

    # Wait before the next iteration, unless it's the last one
    if ($i -lt $numberOfCaptures) {
        Write-Host "[$($i)] $(Get-Date -Format HH:mm:ss): Waiting $delayBetweenCapturesSeconds seconds before next capture..."
        Start-Sleep -Seconds $delayBetweenCapturesSeconds
    }
}

Write-Host "`n--- Capture Process Completed ---" -ForegroundColor Green
Write-Host "Saved $numberOfCaptures CSV capture files to: $outputDirectory"
Read-Host "Press Enter to exit"
<#
.SYNOPSIS
    Forces connection to a specific WiFi network with retry capability.
.DESCRIPTION
    Attempts to connect to a specified WiFi network, with configurable retry attempts
    and intervals. This script uses the netsh command to connect to the network.
.PARAMETER networkName
    The exact name of the WiFi network to connect to.
.PARAMETER maxRetries
    Maximum number of connection attempts before giving up. Defaults to 5.
.PARAMETER retryIntervalSeconds
    Time to wait between retry attempts in seconds. Defaults to 10.
.EXAMPLE
    .\ForceConnectWiFi.ps1 -networkName "MyNetwork_5G" -maxRetries 3 -retryIntervalSeconds 5
.NOTES
    File Name      : ForceConnectWiFi.ps1
    Prerequisite   : PowerShell 5.1 or later
    Copyright      : Scott Anderson 2024
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true,
        Position = 0,
        HelpMessage = "Name of the WiFi network to connect to")]
    [ValidateNotNullOrEmpty()]
    [string]$networkName,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$maxRetries = 5,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 300)]
    [int]$retryIntervalSeconds = 10
)

function Connect-Network {
    <#
    .SYNOPSIS
        Attempts to connect to a specified WiFi network.
    .PARAMETER name
        The name of the network to connect to.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$name
    )
    
    try {
        Write-Verbose "Attempting to connect to $name..."
        $connectionResult = netsh wlan connect name="$name" | Out-String
        Write-Host $connectionResult
    }
    catch {
        Write-Error "Failed to connect to network: $_"
    }
}

function Test-NetworkConnection {
    <#
    .SYNOPSIS
        Checks if currently connected to specified network.
    .PARAMETER name
        The name of the network to check.
    .OUTPUTS
        Boolean indicating connection status
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$name
    )
    
    try {
        $networks = netsh wlan show interfaces | Out-String
        $isConnected = $networks -like "*$name*"
        
        if ($isConnected) {
            Write-Verbose "Connected to $name"
        }
        else {
            Write-Verbose "Not connected to $name"
        }
        
        return $isConnected
    }
    catch {
        Write-Error "Failed to check network connection: $_"
        return $false
    }
}

function Start-ExitCountdown {
    <#
    .SYNOPSIS
        Initiates a countdown before exiting the script.
    .PARAMETER Seconds
        Number of seconds to wait before exit. Default is 3.
    .EXAMPLE
        Start-ExitCountdown -Seconds 5
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 60)]
        [int]$Seconds = 3
    )
    
    try {
        Write-Verbose "Starting exit countdown for $Seconds seconds"
        for ($i = $Seconds; $i -gt 0; $i--) {
            Write-Host "`rExiting in $i seconds..." -NoNewline
            Start-Sleep -Seconds 1
        }
        Write-Host "`rGoodbye!"
        Start-Sleep -Milliseconds 500
    }
    catch {
        Write-Error "Error in countdown: $_"
    }
}

# Main execution block
try {
    Write-Verbose "Initiating connection sequence to $networkName"
    $attemptCount = 0
    $connected = $false

    do {
        $attemptCount++
        Write-Host "Connection attempt $attemptCount of $maxRetries"
        Connect-Network -name $networkName
        
        Write-Verbose "Waiting for connection to establish..."
        Start-Sleep -Seconds 2

        $connected = Test-NetworkConnection -name $networkName

        if (-not $connected -and $attemptCount -lt $maxRetries) {
            Write-Host "Connection attempt failed. Waiting $retryIntervalSeconds seconds..."
            Start-Sleep -Seconds $retryIntervalSeconds
        }
    } while (-not $connected -and $attemptCount -lt $maxRetries)

    if ($connected) {
        Write-Host "Successfully connected to $networkName!"
        Start-ExitCountdown
    }
    else {
        Write-Host "Failed to connect after $maxRetries attempts."
        Write-Host "`nPress any key to exit..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
}
catch {
    Write-Error "An error occurred: $_"
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
# Logging Functionality Script

# Function to log timing information
function Log-Timing {
    <#
    .SYNOPSIS
        Logs timing information for a specific section.
    .PARAMETER section
        The name of the section being logged.
    .PARAMETER startTime
        The start time of the section.
    .PARAMETER endTime
        The end time of the section.
    .OUTPUTS
        None
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$section,
        
        [Parameter(Mandatory = $true)]
        [datetime]$startTime,
        
        [Parameter(Mandatory = $true)]
        [datetime]$endTime
    )
    $duration = $endTime - $startTime
    $logEntry = "$section - Start: $startTime, End: $endTime, Duration: $duration"
    Add-Content -Path "$PSScriptRoot\profile_timing.log" -Value $logEntry
}

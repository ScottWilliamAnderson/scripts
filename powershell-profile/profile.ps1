# PowerShell Profile Script



# Profile Setup

# Check for required environment variables
if (-not $env:USERPROFILE) {
    Write-Host "USERPROFILE environment variable is not set. Skipping profile import."
    return
}

# Import chocolatey profile so it can run refreshenv command
Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1

# Refresh environment variables
refreshenv

# Import posh-git
Import-Module posh-git

# Import oh-my-posh theme
oh-my-posh init pwsh --config "$repoPath\oh-my-posh\plenty-of-info.omp.json" | Invoke-Expression

# Uncomment the following line to enable default behaviour of clearing the terminal screen after the profile setup
# clear


# Useful Functions

# Autoupdate mechanism
function pull-profile {
    # Store the current directory to navigate back
    $currentDir = Get-Location

    # Navigate to the repository directory
    Set-Location $repoPath

    # Pull the latest changes from the repository
    git pull

    # Refresh the PowerShell profile
    . $PROFILE

    # Navigate back to where we started
    Set-Location $currentDir
}

# sudo command to open an admin terminal
function sudo {
    Start-Process -verb RunAs wt
}

# sleep function to pause execution for a specified number of seconds
function sleep {
    param (
        [int]$seconds
    )
    
    Start-Sleep -Seconds $seconds
}

# mklink function to create symbolic links
function mklink { 
    cmd /c mklink $args 
}

# RestGrindTracker

RestGrindTracker is a World of Warcraft Classic addon that tracks XP and kill statistics from mob grinding. It provides a movable UI frame displaying session and total stats, including XP/hour, total kills, rested XP, and estimated time to next level and level 60.

## Features

- Tracks total XP and kills from mob grinding
- Displays rested XP and projected XP gain
- Shows XP/hour and total playtime
- Estimates time to next level and to level 60
- Movable UI frame with persistent position
- Data saved between sessions

## Installation

1. Copy the contents of the `RestGrindTracker` folder to your WoW AddOns directory:
   ```
   C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns
   ```
   Or use the provided deployment script (see below).

2. Restart World of Warcraft Classic and enable the addon in the character select screen.

## Deployment Script

A PowerShell script, [`deploy.ps1`](deploy.ps1), is provided to automate deployment and verify file integrity.

### Usage

1. Set the `RESTGRIND_SOURCE` environment variable to the path of your `RestGrindTracker` source folder. You can use the provided [`env_var_setup.txt`](env_var_setup.txt) as a reference.
2. Run the script:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\deploy.ps1
   ```
   The script will:
   - Copy addon files to the destination directory specified in [`config.json`](config.json)
   - Verify file integrity using SHA256 checksums

## Configuration

- [`config.json`](config.json): Set the destination directory for deployment.
- [`env_var_setup.txt`](env_var_setup.txt): Example command to set the `RESTGRIND_SOURCE` environment variable.

## Files

- [`RestGrindTracker/RestGrindTracker.lua`](RestGrindTracker/RestGrindTracker.lua): Main addon logic
- [`RestGrindTracker/RestGrindTracker.toc`](RestGrindTracker/RestGrindTracker.toc): Addon manifest
- [`deploy.ps1`](deploy.ps1): Deployment and verification script
- [`config.json`](config.json): Deployment configuration
- [`env_var_setup.txt`](env_var_setup.txt): Example environment variable setup

## License

MIT License (or specify your license here)

---

Created by JSko6145
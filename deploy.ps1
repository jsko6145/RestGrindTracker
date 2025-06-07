# if necessary quick and dirty - powershell -ExecutionPolicy Bypass -File .\deploy.ps1
# Read config.json for destinationDir
$config = Get-Content -Path ".\config.json" | ConvertFrom-Json
$destinationDir = $config.destinationDir
Write-Output $destinationDir

# Use system environment variable for sourceDir
$sourceDir = $env:RESTGRIND_SOURCE
Write-Output $env:RESTGRIND_SOURCE

# Check if the environment variable is set
if (-not $sourceDir) {
    Write-Host "❌ Environment variable 'RESTGRIND_SOURCE' is not set. Please set it before running this script."
    exit 1
}

# Copy files
Copy-Item -Path "$sourceDir\*" -Destination $destinationDir -Recurse -Force
Write-Host "✅ Files copied. Starting checksum verification..."

# Function to compute SHA256 hash
function Get-FileHashTable($path) {
    $hashTable = @{}
    Get-ChildItem -Path $path -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($path.Length).TrimStart('\')
        $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256
        $hashTable[$relativePath] = $hash.Hash
    }
    return $hashTable
}

# Get hashes
$sourceHashes = Get-FileHashTable $sourceDir
$destinationHashes = Get-FileHashTable $destinationDir

# Compare hashes
$allMatch = $true
foreach ($key in $sourceHashes.Keys) {
    if ($destinationHashes.ContainsKey($key)) {
        if ($sourceHashes[$key] -ne $destinationHashes[$key]) {
            Write-Host "❌ Mismatch: $key"
            $allMatch = $false
        }
    } else {
        Write-Host "❌ Missing in destination: $key"
        $allMatch = $false
    }
}

if ($allMatch) {
    Write-Host "✅ All files verified. Checksums match!"
} else {
    Write-Host "⚠️ Some files did not match or were missing."
}

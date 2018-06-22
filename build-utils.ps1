Set-StrictMode -version 2.0
$ErrorActionPreference="Stop"

$repoDir = $PSScriptRoot
$binariesDir = Join-Path $repoDir "binaries"

function Create-Directory([string]$dir) {
    New-Item $dir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
}

function Ensure-NuGet() {
    $nuget = Join-Path $binariesDir "nuget.exe"
    if (-not (Test-Path $nuget)) {
        Create-Directory (Split-Path -parent $nuget)
        $version = "4.7.0"
        Write-Host "Downloading NuGet.exe $version"
        $webClient = New-Object -TypeName "System.Net.WebClient"
        $webClient.DownloadFile("https://dist.nuget.org/win-x86-commandline/v$version/NuGet.exe", $nuget)
    }

    return $nuget
}

function Get-PackagesDir() {
    $d = $null
    if ($env:NUGET_PACKAGES -ne $null) {
        $d = $env:NUGET_PACKAGES
    }
    else {
        $d = Join-Path $env:UserProfile ".nuget\packages\"
    }

    Create-Directory $d
    return $d
}

param (
    [string]$destPath = $(throw "Need a path for nuget.exe"),
    [string]$version = $(throw "Need a version"))
set-strictmode -version 2.0
$ErrorActionPreference="Stop"

try
{
    $destDir = split-path -parent $destPath
    mkdir $destDir -ErrorAction SilentlyContinue | out-null

    if (test-path $destPath) {
        exit 0
    }

    write-host "Downloading NuGet.exe"
    $webClient = New-Object -TypeName "System.Net.WebClient"
    $webClient.DownloadFile("https://dist.nuget.org/win-x86-commandline/v$version/NuGet.exe", $destPath)
    exit 0
}
catch [exception]
{
    write-host $_.Exception
    exit -1
}

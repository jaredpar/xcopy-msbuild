param (
    [string]$nugetVersion = "3.6.0-beta1",
    [string]$destDir = "")
set-strictmode -version 2.0
$ErrorActionPreference="Stop"

try
{
    if ($destDir -eq "") { 
        $destDir = join-path $PSScriptRoot "../binaries/tools"
    }

    mkdir $destDir -ErrorAction SilentlyContinue | out-null

    $destFile = join-path $destDir "NuGet.exe"

    if (test-path $destFile) {
        exit 0
    }

    write-host "Downloading NuGet.exe"
    $webClient = New-Object -TypeName "System.Net.WebClient"
    $webClient.DownloadFile("https://dist.nuget.org/win-x86-commandline/v$nugetVersion/NuGet.exe", $destFile)
    exit 0
}
catch [exception]
{
    write-host $_.Exception
    exit -1
}

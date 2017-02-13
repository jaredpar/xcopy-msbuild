param (
    [string]$nuget = $(throw "Need a path to nuget.exe"),
    [string]$packagesDir = $(throw "Need a packages directory"))
set-strictmode -version 2.0
$ErrorActionPreference="Stop"

try
{
    $lines = @()
    $lines += '<?xml version="1.0" encoding="utf-8"?>'
    $lines += '<packages>'
    foreach ($data in gc (join-path $PSScriptRoot "packages.txt")) {
        $all = $data.split(':')
        $lines += "  <package id=`"$($all[0])`" version=`"$($all[1])`" />"
    }
    $lines += '</packages>'

    $configDir = join-path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString("n"))
    $configFilePath = join-path $configDir "packages.config"
    mkdir $configDir | out-null

    $lines | out-file -encoding UTF8 $configFilePath
    & $nuget restore $configFilePath -PackagesDirectory $packagesDir | out-null
}
catch [exception]
{
    write-host $_.Exception
    exit -1
}


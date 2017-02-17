param ([string]$msbuildPath = $(throw "Need a path to MSBuild"),
       [string]$version = $(throw "Need a package version"))

$nuget = join-path $PSScriptroot "..\binaries\Tools\NuGet.exe"

& $nuget pack nuget-legacy.nuspec -Properties msbuildPath=$msbuildPath`;version=$versio

